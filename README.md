# Jenkins

### Instalar o Jenkins no Kubernetes:

- `git clone git@github.com:diegofnunesbr/jenkins.git`
- `cd jenkins`
- `helm install --create-namespace jenkins -n jenkins .`

### Configurar o Jenkins no arquivo hosts do Windows:

- `sudo tee -a /mnt/c/Windows/System32/drivers/etc/hosts <<< "$(ifconfig eth0 | grep 'inet ' | awk '{print $2}') jenkins.local"`

### Remover o Jenkins no Kubernetes:

- `helm uninstall jenkins -n jenkins`
