@Library('shared-libraries') _

pipeline {
  agent any

  parameters {
    string(name: 'TARGET', defaultValue: 'vm-test', description: 'Host do inventário Ansible')
  }

  stages {
    stage('Deploy') {
      steps {
        deployHomelab(params.TARGET)
      }
    }
  }
}
