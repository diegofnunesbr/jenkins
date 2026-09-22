# jenkins

Instalação do **Jenkins** via chart oficial (`jenkins/jenkins`), usando
Application multi-source do Argo CD (mesmo padrão do repositório
`grafana`), e o pipeline de exemplo do homelab que usa a Shared Library
do repositório `shared-libraries` pra provisionar (Terraform) e
configurar (Ansible) VMs.

## Pré-requisitos

- `Kubernetes` instalado
- `kubectl` e `kubeseal` instalados
- ArgoCD instalado (ver repositório `argocd`)
- `Sealed Secrets` e `cert-manager` instalados (via `core-config` do
  repositório `argocd` e repositório `cert-manager`)
- `ingress-nginx` instalado (via `core-config` do repositório `argocd`)
- DNS `jenkins.diegofnunesbr.com` apontando pro node (ver repositório `dns`)

## Estrutura do repositório

```text
jenkins/
├── applications/
│   └── argocd.jenkins.yaml     # Application multi-source do Argo CD
├── values.yaml                 # values do chart oficial jenkins/jenkins
├── Dockerfile                  # imagem custom: chart + Terraform/Terragrunt/Ansible/git/ssh
├── build.sh                    # builda a imagem e importa pro containerd do k0s
├── Jenkinsfile                 # pipeline declarativo, chama a shared-libraries
└── README.md
```

## 1. Clonar e buildar a imagem custom (Terraform/Terragrunt/Ansible/git/ssh)

O chart oficial não inclui essas ferramentas - `values.yaml` já aponta
`controller.image` pra uma imagem local (`docker.io/library/jenkins-homelab:local`,
`pullPolicy: IfNotPresent`), que precisa existir no cluster **antes** de
aplicar a Application (senão o pod fica em `ImagePullBackOff`):

```bash
git clone https://github.com/diegofnunesbr/jenkins.git
cd jenkins
./build.sh
```

Isso roda `docker build` a partir do `Dockerfile` (base `jenkins/jenkins`
+ Terraform `1.16.3` + Terragrunt `1.1.5` + Ansible `14.4.0` + `git` +
`openssh-client`) e importa a imagem pro containerd do k0s via
`k0s ctr images import` - mesmo mecanismo do `deploy.sh` do repositório
`rundeck`, sem precisar de um registry.

**`docker build -t jenkins-homelab:local` não gera a tag `jenkins-homelab:local`
sozinha** - o Docker insere `library/` automaticamente em nomes de imagem
de um segmento só quando referenciados com registry completo
(`docker.io/jenkins-homelab:local` vira `docker.io/library/jenkins-homelab:local`).
Se mudar o nome da imagem no `build.sh`, ajuste `controller.image.repository`
em `values.yaml` pra bater exatamente (confira com
`sudo k0s ctr images ls | grep jenkins-homelab` se ficar em dúvida).

Rode `./build.sh` de novo sempre que o `Dockerfile` mudar (nova versão do
Terraform/Ansible, etc.) e reinicie o pod (`kubectl delete pod jenkins-0 -n jenkins`)
pra ele pegar a imagem nova.

## 2. Criar o namespace e o SealedSecret jenkins-admin-secret

O namespace precisa existir **antes** de criar o secret (a Application
também cria ele via `CreateNamespace=true`, mas só na hora do sync, que
ainda não rolou nesse ponto):

```bash
kubectl create namespace jenkins
printf '%s' 'admin' > /tmp/admin-user
printf '%s' 'SUA_SENHA_AQUI' > /tmp/admin-password
kubectl create secret generic jenkins-admin-secret -n jenkins \
  --from-file=jenkins-admin-user=/tmp/admin-user \
  --from-file=jenkins-admin-password=/tmp/admin-password \
  --dry-run=client -o yaml > unsealed.secret.yaml
kubeseal --scope cluster-wide --format yaml < unsealed.secret.yaml > sealed.secret.yaml
rm -f /tmp/admin-user /tmp/admin-password unsealed.secret.yaml
kubectl apply -f sealed.secret.yaml
rm -f sealed.secret.yaml
```

## 3. Instalar o Jenkins

```bash
kubectl apply -f applications/argocd.jenkins.yaml
```

**Lembrete:** a Application aponta pro GitHub (`repoURL`), não pro seu
clone local - qualquer mudança em `values.yaml`/`Dockerfile` só tem
efeito depois de `git push` (e um sync, automático ou forçado via
`kubectl -n argocd patch application jenkins --type merge -p '{"operation":{"sync":{}}}'`).

`values.yaml` já configura:
- `Ingress` com TLS automático via cert-manager (`jenkins.diegofnunesbr.com`)
- plugins padrão do chart (`kubernetes`, `workflow-aggregator`/Pipeline, `git`,
  `configuration-as-code`) + SSH Agent (`ssh-agent`) e Pipeline Groovy
  Libraries (`workflow-cps-global-lib`) via `additionalPlugins`
- a Global Pipeline Library `shared-libraries` já pré-configurada via
  JCasC (`Manage Jenkins → System → Global Pipeline Libraries` já vem
  preenchido, sem passo manual)
- `numExecutors: 2` no controller - o pipeline de exemplo roda direto nele,
  sem agente dinâmico (mesmo com o plugin `kubernetes` instalado)

**Não mexa no plugin `kubernetes`:** ele parece dispensável (não usamos
agentes dinâmicos aqui), mas o `defaultConfig: true` do chart sempre gera
um bloco `clouds: [kubernetes]` no JCasC, e removê-lo sem também desligar
`controller.JCasC.defaultConfig` derruba o Jenkins no boot com
`UnknownAttributesException: cloud: No hudson.slaves.Cloud implementation
found for kubernetes`. `agent.enabled: false` **não** resolve isso (só
afeta o pod template padrão, não a config da cloud em si).

**Instalação inicial pode demorar:** o `kubernetes` plugin puxa uma
árvore grande de dependências, e os mirrors do Jenkins
(`ftp-nyc.osuosl.org` e outros) ocasionalmente ficam lentos/instáveis,
travando o download sem timeout algum (Java não define um por padrão).
Por isso `initContainerEnv` já seta `JAVA_TOOL_OPTIONS` com
`connectTimeout`/`readTimeout` - sem isso, um mirror travado pode prender
o init container indefinidamente em vez de cair no retry (`attempt N de
3`) que a própria ferramenta já tenta fazer.

**`initializeOnce: true` é obrigatório, não é só otimização.** O script
`apply_config.sh` do chart oficial (gerado a partir de
`templates/config.yaml`) tem uma linha `yes n | cp -i .../plugins/*
/var/jenkins_plugins/` que **trava de verdade** (confirmado com teste
isolado, `timeout 5` matou o processo, não terminou sozinho) sempre que
o destino já tem arquivos - o que acontece em qualquer restart do
container (o volume `EmptyDir` sobrevive a reinícios de container
dentro do mesmo pod, só se limpa quando o *pod* inteiro é recriado). Sem
`initializeOnce`, um simples restart do container (ex.: reboot da
máquina host) deixa o Jenkins preso em `CrashLoopBackOff` indefinidamente
até alguém apagar o pod manualmente (`kubectl delete pod jenkins-0 -n
jenkins`).

Com `initializeOnce: true`, o script inteiro só roda na primeira
inicialização - ele cria `$JENKINS_HOME/initialization-completed` (no
PVC, persistente) e, a partir daí, qualquer restart sai logo na primeira
linha (`controller was previously initialized, refusing to
re-initialize`), nunca chegando perto do `cp` problemático.

**Trade-off:** depois da primeira subida, mudanças em plugins/JCasC no
`values.yaml` não são mais aplicadas automaticamente nos restarts
seguintes. Pra forçar uma reinicialização completa (ex.: depois de
adicionar um plugin novo), apague o marcador antes de reiniciar o pod:

```bash
kubectl -n jenkins exec jenkins-0 -c jenkins -- rm -f /var/jenkins_home/initialization-completed
kubectl -n jenkins delete pod jenkins-0
```

## 4. Cadastrar as credenciais (SSH e Proxmox)

Isso não é automatizável com segurança por aqui, porque envolve segredo
real (chave privada, API token) - cadastre direto na UI:

`Manage Jenkins → Credentials → System → Global credentials → Add Credentials`

| Tipo | ID sugerido | Conteúdo |
|---|---|---|
| SSH Username with private key | `proxmox-ssh-key` | usuário `diegofnunesbr`, a mesma chave privada usada pelo Terraform pra acessar o Proxmox via SSH (upload do cloud-init) |
| Secret text | `proxmox-api-token` | o token gerado em `pveum user token add terraform@pve terraform` (repositório `terraform`) |

O `Jenkinsfile`/`shared-libraries` referencia essas credenciais pelo ID -
ajuste os nomes lá se cadastrar com IDs diferentes.

## Acessar

```text
https://jenkins.diegofnunesbr.com
```

Login `admin` + senha do SealedSecret gerado acima. Certificado real
(Let's Encrypt, renovado automaticamente pelo cert-manager) - sem porta
na URL, o `ingress-nginx` escuta direto em `80`/`443` via `hostNetwork`.

## Configurar o pipeline

Criar um job "Pipeline" (ou "Multibranch Pipeline") apontando pro
`Jenkinsfile` deste repositório, com acesso de checkout aos repositórios
`terraform` e `ansible` (via submodule, ou copiando os diretórios pro
workspace antes de rodar).

## Remover o Jenkins

```bash
cd jenkins
kubectl delete -f applications/argocd.jenkins.yaml
```
