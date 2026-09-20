# ADR 0001: Usar Shared Library em vez de Jenkinsfile duplicado

## Contexto

Cada novo pipeline do homelab precisaria repetir os mesmos passos
(Terraform + Ansible). Duplicar isso em cada `Jenkinsfile` dificulta
manter/corrigir depois.

## Decisão

Centralizar os passos reutilizáveis nesta Shared Library (`vars/`, `src/`,
`resources/`), seguindo a convenção oficial do Jenkins. Pipelines
individuais só chamam `@Library('homelab') _` e usam as funções daqui.

## Consequências

- Corrigir um bug de infraestrutura (ex.: um passo do Terraform) muda só
  este repositório, não cada pipeline.
- Pipelines individuais ficam pequenos e legíveis.
- Mudanças aqui afetam todo pipeline que usa a library - testar antes de
  fazer merge na branch usada como `Default version`.
