import homelab.GitHelper

def call(String target) {
  def git = new GitHelper(this)
  echo "Deploy do commit ${git.shortCommitSha()} pra ${target}"

  dir('terraform/environments/homelab') {
    sh 'terraform init -input=false'
    sh 'terraform apply -auto-approve'
  }

  dir('ansible') {
    sh "ansible-playbook playbooks/site.yml --limit ${target}"
  }
}
