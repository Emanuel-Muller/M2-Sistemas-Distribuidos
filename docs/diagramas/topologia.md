# Topologia do laboratório

Diagrama da topologia observada no E1 (`experimentos/E1/redes.json` e `experimentos/E1/soa.txt`). Usa só nomes e endereços que aparecem nesses arquivos. Cada autoritativo participa das duas redes.

```mermaid
flowchart TB
  subgraph clientes["rede sdlab_clientes 172.31.0.0/24 (gateway 172.31.0.1)"]
    direction LR
    cliente["cliente<br/>172.31.0.100"]
    cliente2["cliente2<br/>172.31.0.101"]
    resolvedor["resolvedor<br/>172.31.0.53"]
  end
  subgraph auto["autoritativos (conectados às duas redes)"]
    direction LR
    ns1["ns1 primário<br/>interna 172.30.0.11<br/>clientes 172.31.0.11"]
    ns2["ns2 secundário<br/>interna 172.30.0.12<br/>clientes 172.31.0.12"]
    ns3["ns3 secundário<br/>interna 172.30.0.13<br/>clientes 172.31.0.13"]
  end
  ns1 -->|"transferência da zona, rede sdlab_interna 172.30.0.0/24"| ns2
  ns1 -->|"transferência da zona, rede sdlab_interna 172.30.0.0/24"| ns3
  cliente -->|"dig SOA (soa.txt)"| auto
```

- `sdlab_interna` (172.30.0.0/24, gateway 172.30.0.1) tem só ns1, ns2 e ns3.
- `sdlab_clientes` (172.31.0.0/24, gateway 172.31.0.1) tem os três autoritativos, o resolvedor, o cliente e o cliente2.
- O resolvedor, o cliente e o cliente2 não estão na rede interna.
