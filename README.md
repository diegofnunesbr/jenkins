# jenkins

Pipeline como código: o `Jenkinsfile` orquestra `terraform` + `ansible` pra
provisionar e configurar VMs do homelab. `vars/` é uma Shared Library,
reaproveitável em outros Jenkinsfiles do ambiente.

## Pré-requisitos

- Jenkins com os plugins Pipeline, Git e SSH Agent
- Credenciais SSH e do Proxmox cadastradas no Jenkins (Credentials)
- Terraform e Ansible instalados no agente que vai rodar o pipeline

## Estrutura do repositório

```text
jenkins/
├── Jenkinsfile                    # pipeline declarativo principal
└── vars/
    └── deployHomelab.groovy       # função reaproveitável (Shared Library)
```

## Configurar como Shared Library

Manage Jenkins → System → Global Pipeline Libraries:

| Campo | Valor |
|---|---|
| Name | `homelab` |
| Default version | `main` |
| Retrieval method | Modern SCM → Git |
| Repository URL | `https://github.com/diegofnunesbr/jenkins.git` |

Uso em outro Jenkinsfile:

```groovy
@Library('homelab') _
deployHomelab('vm-test')
```

## Configurar o pipeline principal

Criar um job "Pipeline" (ou "Multibranch Pipeline") apontando pro
`Jenkinsfile` deste repositório, com acesso de checkout aos repositórios
`terraform` e `ansible` (via submodule, ou copiando os diretórios pro
workspace antes de rodar).
