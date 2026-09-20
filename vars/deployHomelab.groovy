def call(String target) {
  dir('terraform/environments/homelab') {
    sh 'terraform init -input=false'
    sh 'terraform apply -auto-approve'
  }

  dir('ansible') {
    sh "ansible-playbook playbooks/site.yml --limit ${target}"
  }
}
