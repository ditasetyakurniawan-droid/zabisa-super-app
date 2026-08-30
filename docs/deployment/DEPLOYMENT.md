# DT deployment

Target nodes and internal addresses belong in infrastructure inventory, not business source code. Configure API DNS, MySQL hostname, Harbor, SonarQube, ELK and Vault through environment/GitOps values. All application workloads run as non-root with dropped capabilities, seccomp RuntimeDefault, probes, resource requests/limits and at least two replicas for critical services.
