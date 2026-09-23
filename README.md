# Firewall + DMZ: Segurança de Perímetro e Defense in Depth

**Disciplina:** Segurança de Redes<br>
**Autores:** Pedro Augusto Santos da Silva e Christianny Kelly Silva dos Santos<br>
**Ambiente de Execução:** Windows, Docker Desktop e Kathará<br>

---

## 1. Visão Geral do Processo

Antes da apresentação dos resultados técnicos, detalha-se o procedimento adotado para possibilitar a reprodução do experimento.

Inicialmente, foi estruturado o diretório principal do projeto, denominado `firewall-dmz-lab`. Em seu interior, foram criados o arquivo `lab.conf` — descrevendo a topologia especificada — e os diretórios dos nós da rede: o roteador de borda (`r0`), o firewall/middlebox (`fw`), as duas estações da LAN (`pc1` e `pc2`), os dois servidores da DMZ (`web` e `dns`) e a estação de gerência (`adm`). Para cada um desses nós, foi elaborado o respectivo arquivo `.startup`, responsável por configurar o endereçamento IP de cada interface de rede conforme o plano de endereçamento previsto (LAN em `10.0.1.0/24`, DMZ em `10.0.2.0/24`, MGMT em `10.0.3.0/24` e WAN simulando a Internet em `198.51.100.0/30`). Adicionalmente, habilitou-se o encaminhamento de pacotes (`ip_forward`) nos nós `r0` e `fw`, haja vista que ambos atuam como roteadores na topologia.

Após a finalização das configurações, o ambiente de laboratório foi inicializado por meio do comando `kathara lstart`. Na sequência, realizou-se a validação primária de conectividade: a estação `pc1` efetuou com sucesso o envio de pacotes ICMP (ping) para o servidor web da DMZ (`10.0.2.10`), confirmando o correto funcionamento do roteamento inter-redes antes da aplicação das regras do firewall.

<img width="708" height="482" alt="image (1)" src="https://github.com/user-attachments/assets/29c8429e-0364-48b6-9a33-5bd2f80c6ebd" />

A partir desse ponto, seguiu-se o ciclo metodológico proposto na atividade. A política de segurança foi aplicada camada por camada: primeiramente a política de perímetro (default deny), seguida pelos testes isolados nas camadas de Enlace (L2/MAC), Rede (L3/ICMP e IP) e Transporte (L4/Portas).

---

## 2. Topologia Implementada

A topologia de rede foi configurada conforme o planejamento estabelecido:

**Tabela 1 – Plano de Endereçamento e Topologia de Rede**

| Rede | Sub-rede         | Uso                    | Gateway              |
|------|------------------|------------------------|----------------------|
| WAN  | 198.51.100.0/30  | Link Roteador–ISP      | 198.51.100.2 (r0)    |
| LAN  | 10.0.1.0/24      | Rede Interna           | 10.0.1.1 (fw eth1)   |
| DMZ  | 10.0.2.0/24      | Servidores Públicos    | 10.0.2.1 (fw eth2)   |
| MGMT | 10.0.3.0/24      | Gerência do Firewall   | 10.0.3.1 (fw eth3)   |

*Fonte: Autores.*

**Nós da rede:** `r0` (Roteador de borda/NAT), `fw` (Firewall stateful/middlebox), `pc1` e `pc2` (Estações LAN), `web` e `dns` (Servidores DMZ) e `adm` (Estação de Gerência).

Todos os 7 containers foram iniciados com sucesso via `kathara lstart`, e a conectividade básica entre LAN e DMZ foi estabelecida como linha de base (baseline) para os experimentos subsequentes.

---

## 3. Segurança de Perímetro

Adotou-se o princípio do **Default Deny** (bloqueio por padrão, liberando apenas o tráfego estritamente necessário). As políticas padrão das chains `INPUT` e `FORWARD` foram definidas como `DROP`. A filtragem foi configurada de forma stateful, estabelecendo a diferenciação entre novas conexões (`NEW`) e tráfego de retorno de conexões previamente autorizadas (`ESTABLISHED,RELATED`).

```bash
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
```

<img width="1177" height="178" alt="Captura de tela 2026-09-22 220847" src="https://github.com/user-attachments/assets/466982e0-046e-4f26-b812-e3f3a5558d52" />


### 3.1 Matriz de Fluxos de Comunicação

**Tabela 2 – Matriz de Fluxos de Comunicação**

| Comunicação                          | Política  | Status                                   |
|---------------------------------------|-----------|-------------------------------------------|
| LAN → Internet                        | Permitir  | Implementado                               |
| LAN → Web/DNS da DMZ                   | Permitir  | Implementado e testado                     |
| Internet → Web da DMZ                 | Permitir  | Implementado                               |
| Internet → LAN                        | Bloquear  | Coberto pela política padrão (DROP)        |
| DMZ → LAN (novas conexões)            | Bloquear  | Coberto pela política padrão (DROP)        |
| Respostas de conexões permitidas      | Permitir  | Implementado (stateful)                    |

*Fonte: Autores.*

---

## 4. Experimentos por Camada

### 4.1 Camada 2 (Enlace): Bloqueio por Endereço MAC

**Cenário:** A estação `pc2` foi simulada como um dispositivo comprometido gerando tráfego malicioso.

1. Identificou-se o endereço MAC da interface `eth0` do `pc2` por meio do comando `ifconfig eth0`.

<img width="708" height="497" alt="WhatsApp Image 2026-09-22 at 17 55 16 (10)" src="https://github.com/user-attachments/assets/ea94cc4f-3a6f-4d40-bda6-71badc0c384a" />


2. Aplicou-se a regra de bloqueio no nó `fw`, posicionando-a no topo da chain `FORWARD` para garantir prioridade de avaliação:

```bash
iptables -I FORWARD 1 -m mac --mac-source 96:35:1b:b8:6b:9c -j DROP
```

- `pc1 → ping 10.0.2.10`: Tráfego transcorreu sem interrupções.
<img width="708" height="343" alt="123" src="https://github.com/user-attachments/assets/2701f3e3-ddfe-4090-9982-fcf813d70bd8" />

- `pc2 → ping 10.0.2.10`: Ocorreu falha na comunicação (Destination Host Unreachable).
<img width="601" height="80" alt="1233" src="https://github.com/user-attachments/assets/3df3adcb-0c23-44be-81a9-ae50f10f238c" />

Ficou perceptível que o endereço MAC possui validade restrita ao segmento de rede local (domínio de broadcast/enlace), ele não acompanha o pacote por todo o percurso da rede. Ao atravessar um roteador, o cabeçalho de enlace é reescrito, assumindo como MAC de origem o endereço da interface de saída do próprio roteador. Dessa forma, a filtragem por MAC só é efetiva porque o firewall `fw` compartilha o mesmo segmento Ethernet da estação `pc2` (conectados ao mesmo switch virtual da LAN). Não seria possível filtrar por MAC um dispositivo localizado além de um roteador externo (ex.: tráfego originado na Internet).

### 4.2 Camada 3 (Rede)

**A) Bloqueio de ICMP entre LAN e DMZ**

```bash
iptables -I FORWARD 1 -p icmp -i eth1 -o eth2 -j DROP
```
<img width="787" height="45" alt="image (11)" src="https://github.com/user-attachments/assets/4be5e7f0-8a3a-44d3-9003-22d4fa0bae0c" />

Em teste efetuado a partir do `pc1` (`ping 10.0.2.10`), observou-se a interrupção completa da comunicação. Após o registro da evidência, a regra foi removida para preservar o ambiente dos testes subsequentes:

<img width="590" height="60" alt="image (12)" src="https://github.com/user-attachments/assets/7ccde221-7e3b-4700-a287-825511fd8a17" />


```bash
iptables -D FORWARD -p icmp -i eth1 -o eth2 -j DROP
```

<img width="787" height="45" alt="image (14)" src="https://github.com/user-attachments/assets/b9659b59-55be-4ef0-8db8-8824df43f4b2" />


**B) Bloqueio de Endereço IP de Destino Específico**

Para simular a restrição a um destino não autorizado na organização, bloqueou-se o acesso da LAN ao IP `10.0.3.100`:

```bash
iptables -I FORWARD 1 -d 10.0.3.100 -j DROP
```
<img width="672" height="40" alt="image (16)" src="https://github.com/user-attachments/assets/d91b176d-a8a2-43e7-957d-ce0eeaeeb3cf" />


O teste de ping a partir de `pc1` resultou em ausência de resposta, confirmando a efetividade da restrição.

<img width="626" height="63" alt="image (15)" src="https://github.com/user-attachments/assets/f4aeb0a4-75ca-47fe-82e3-1ff1472d2a21" />


O bloqueio por endereço IP não se mostra uma solução definitiva para restringir sites. A filtragem exclusivamente por IP apresenta limitações. Um mesmo domínio web pode estar associado a múltiplos IPs (mecanismos de load balancing ou CDNs), o que permite contornar o bloqueio caso o endereço mude. Além disso, um único IP pode hospedar diversos serviços ou domínios em servidores compartilhados, de modo que o bloqueio de um IP específico pode indisponibilizar serviços legítimos correlacionados.

### 4.3 Camada 4 (Transporte): Bloqueio de Serviços P2P (BitTorrent)

Efetuou-se o bloqueio da faixa de portas padrão utilizadas pelo protocolo BitTorrent (TCP/UDP 6881–6889), inserindo as regras no início da chain:

```bash
iptables -I FORWARD 1 -p tcp --dport 6881:6889 -j DROP
iptables -I FORWARD 1 -p udp --dport 6881:6889 -j DROP
```

<img width="1024" height="409" alt="image (2)" src="https://github.com/user-attachments/assets/8a01ec1b-c2b3-41e1-ba4f-3eed2595288e" />


**Análise do comportamento e ordenação das regras:**

Nos testes iniciais utilizando `nc -zv -w 3 10.0.2.10 6881`, obteve-se o retorno `Connection refused`. Esse comportamento indicou que os pacotes estavam atingindo o host de destino, pois a regra de bloqueio havia sido anexada ao final da lista (`-A`), sendo precedida por regras permissivas gerais.

Após a correção no posicionamento das regras no início da chain (`-I FORWARD 1`), o teste com `nc` passou a retornar `timed out: Operation now in progress`. O resultado de timeout confirmou que o firewall passou a descartar (DROP) os pacotes preventivamente no perímetro.

<img width="941" height="63" alt="WhatsApp Image 2026-09-22 at 17 55 16 (12)" src="https://github.com/user-attachments/assets/94d6b236-9b65-47eb-b82d-f8a9bed2c8eb" />

O bloqueio de portas estáticas não garante a interrupção total do tráfego P2P. Clientes P2P modernos utilizam técnicas como alocação dinâmica de portas altas, e navegação via portas convencionais (ex.: 80/HTTP ou 443/HTTPS) e criptografia de cabeçalhos, contornando mecanismos de inspeção baseados estritamente em portas L4.

### 4.4 Camada 7 (Aplicação): Proposta de Controle Avançado

Diante das limitações identificadas nas Camadas 3 e 4, a abordagem recomendada consiste no emprego de **Firewalls de Próxima Geração (NGFW)** dotados de **Deep Packet Inspection (DPI)**.

Enquanto a filtragem convencional analisa apenas os cabeçalhos das Camadas 3 e 4, a tecnologia DPI realiza a inspeção da carga útil (payload) dos pacotes, viabilizando:

- **Análise por Assinatura**: identificação de padrões específicos de protocolos no conteúdo dos pacotes (ex.: handshake do BitTorrent), independentemente da porta utilizada.
- **Análise Comportamental (Heurística)**: monitoramento do padrão de conexões dos hosts (por exemplo, a abertura massiva e simultânea de conexões para múltiplos IPs), permitindo mitigar tráfegos maliciosos ou não autorizados.

---

## 5. Defesa em Profundidade (Defense in Depth)

Verifica-se que, na hipótese de o servidor Web da DMZ ser totalmente comprometido, não é certo que o atacante terá acesso direto à rede interna (LAN). A arquitetura implementada adota o princípio de **Defesa em Profundidade (Defense in Depth)**, no qual a segurança é distribuída em múltiplas camadas independentes.

A política de segurança configurada no `fw` autoriza o tráfego da DMZ em direção à LAN exclusivamente quando este pertence a uma conexão pré-existente (`ESTABLISHED,RELATED`), originada a partir da LAN. Portanto, mesmo sob o controle do servidor web, um atacante não consegue iniciar novas conexões (`NEW`) em direção às estações `pc1` ou `pc2`, visto que a política padrão da chain `FORWARD` permanece definida como `DROP`.

Contribuem para essa proteção:

- **Segmentação de rede**: separação física e lógica entre as sub-redes LAN, DMZ e MGMT em interfaces distintas no firewall.
- **Princípio do menor privilégio**: concessão estrita dos privilégios e portas necessários para a operação do servidor web.

---

## 6. Solução de Problemas (Troubleshooting)

Durante o processo de boot do nó `fw`, identificou-se o seguinte alerta nos registros do sistema:

```
/hostlab/fw.startup: line 8: /proc/sys/net/ipv4/ip_forward: Read-only file system
```

Esse comportamento decorre de restrições de segurança impostas por ambientes em container Docker para a escrita direta no sistema de arquivos `/proc`. Verificou-se que o aviso não impactou o roteamento do laboratório, visto que a plataforma Kathará gerencia o encaminhamento de pacotes de forma nativa nos nós atribuídos como roteadores.

---

## 7. Perguntas Finais da Atividade

**1. Quem pode se comunicar com quem?**

A LAN pode iniciar conexões livremente para a Internet e para a DMZ. A Internet possui permissão de acesso restrita ao servidor Web da DMZ nas portas 80 e 443. A DMZ não possui permissão para iniciar novas conexões com destino à LAN.

**2. Que tipos de comunicação são permitidos ou bloqueados?**

- **Permitidos:** Fluxos LAN → Internet, LAN → DMZ, Internet → Web DMZ (80/443) e tráfego de retorno de conexões autorizadas.
- **Bloqueados por padrão:** Todo o tráfego não especificado (incluindo Internet → LAN e novas conexões DMZ → LAN).
- **Bloqueios específicos testados:** Endereço MAC da estação `pc2` (Enlace), tráfego ICMP entre LAN e DMZ (Rede), IP de destino restrito (Rede) e portas do protocolo BitTorrent (Transporte).

**3. Se uma camada de segurança falhar, quais outras continuam protegendo a infraestrutura?**

Em caso de comprometimento do servidor Web na DMZ, a política stateful do firewall e a segmentação de redes impedem o avanço do atacante em direção à LAN, evidenciando na prática o conceito de Defesa em Profundidade.
