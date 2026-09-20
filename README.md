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
- `Sealed Secrets` instalado

## Estrutura do repositório

```text
jenkins/
├── applications/
│   └── argocd.jenkins.yaml     # Application multi-source do Argo CD
├── values.yaml                 # values do chart oficial jenkins/jenkins
├── Jenkinsfile                 # pipeline declarativo, chama a shared-libraries
└── README.md
```

## Gerar o SealedSecret jenkins-admin-secret

```bash
printf '%s' 'admin' > /tmp/admin-user
printf '%s' 'SUA_SENHA_AQUI' > /tmp/admin-password
kubectl create secret generic jenkins-admin-secret -n jenkins \
  --from-file=jenkins-admin-user=/tmp/admin-user \
  --from-file=jenkins-admin-password=/tmp/admin-password \
  --dry-run=client -o yaml > unsealed.secret.yaml
kubeseal --scope cluster-wide --format yaml < unsealed.secret.yaml > sealed.secret.yaml
rm -f /tmp/admin-user /tmp/admin-password unsealed.secret.yaml
kubectl apply -f sealed.secret.yaml
```

O namespace `jenkins` já deve existir no cluster antes desse passo (ou
crie manualmente - a Application também tem `CreateNamespace=true`, mas
o `kubectl create secret` acima roda antes dela).

## Instalar o Jenkins

```bash
git clone https://github.com/diegofnunesbr/jenkins.git
cd jenkins
kubectl apply -f applications/argocd.jenkins.yaml
```

`values.yaml` já configura:
- `NodePort` fixo na porta `30880`
- plugins Git e Pipeline (`workflow-aggregator`, padrão do chart) + SSH Agent
  (`ssh-agent`) e Pipeline Groovy Libraries (`workflow-cps-global-lib`)
- a Global Pipeline Library `shared-libraries` já pré-configurada via
  JCasC (`Manage Jenkins → System → Global Pipeline Libraries` já vem
  preenchido, sem passo manual)

**Faltando ainda:** o pipeline (`Jenkinsfile`) roda no próprio controller
(`numExecutors: 2`, sem agentes Kubernetes dinâmicos) e o chart oficial
não inclui Terraform/Ansible na imagem - pra `deployHomelab()` funcionar
de verdade, ainda é preciso instalar esses binários no pod do controller
(via `initContainers`/imagem customizada) e cadastrar as credenciais SSH
e do Proxmox em `Manage Jenkins → Credentials`.

## Acessar

```text
http://<ip-do-node-k0s>:30880
```

Login `admin` + senha do SealedSecret gerado acima.

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
