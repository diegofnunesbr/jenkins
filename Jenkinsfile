pipeline {
  agent any

  parameters {
    string(name: 'TARGET', defaultValue: 'vm-test', description: 'Host do inventário Ansible')
  }

  stages {
    stage('Terraform Plan') {
      steps {
        dir('terraform/environments/homelab') {
          sh 'terraform init -input=false'
          sh 'terraform plan -out=tfplan'
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        dir('terraform/environments/homelab') {
          sh 'terraform apply -input=false tfplan'
        }
      }
    }

    stage('Ansible') {
      steps {
        dir('ansible') {
          sh "ansible-playbook playbooks/site.yml --limit ${params.TARGET}"
        }
      }
    }
  }
}
