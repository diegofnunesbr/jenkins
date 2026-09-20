# jenkins

Pipeline de exemplo do homelab, usando a Shared Library do repositório
`shared-libraries` pra provisionar (Terraform) e configurar (Ansible) VMs.

## Pré-requisitos

- Jenkins com os plugins Pipeline, Git e SSH Agent
- Repositório `shared-libraries` configurado como Global Pipeline Library
  (chamada `shared-libraries`) - ver README daquele repositório
- Credenciais SSH e do Proxmox cadastradas no Jenkins (Credentials)
- Terraform e Ansible instalados no agente que vai rodar o pipeline

## Estrutura do repositório

```text
jenkins/
└── Jenkinsfile                    # pipeline declarativo, chama a shared-libraries
```

## Configurar o pipeline

Criar um job "Pipeline" (ou "Multibranch Pipeline") apontando pro
`Jenkinsfile` deste repositório, com acesso de checkout aos repositórios
`terraform` e `ansible` (via submodule, ou copiando os diretórios pro
workspace antes de rodar).
