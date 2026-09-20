package homelab

class GitHelper implements Serializable {
  def steps

  GitHelper(steps) {
    this.steps = steps
  }

  String shortCommitSha() {
    return steps.sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
  }
}
