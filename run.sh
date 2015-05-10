#!/usr/bin/env bash

#criação e configuração automatizada de um shard com
#replicação no mongodb

#Parâmetros:
declare MONGODB_PORTA=27017
declare REPLICADORES=3
declare GRP_REPLICADORES=2
declare CFG_SERVERS=3
declare TEMPO_ESPERA_SUBIDA_CONFIG_SERVERS=5
declare PREFIXO_REPLICADORES=repl
declare PREFIXO_CONFIGURADORES=cfg

#Variáveis internas
declare IPS_PRIMARY
declare -A IPS
declare -A IPS_REP

#Recebe
#       $1 qtd replications sets
#       $2 qtd replications servers
#       $3 prefixo do nome do container
#       $4 função que será executada dentro de cada maquina
function seqMaquinas() {
  for grp in $(seq 1 $1)
  do
    echo "Grupo $grp"

    for srv in $(seq 1 $2)
    do
      echo "[Grupo $grp] Servidor $srv"
        #ponto de execução da funcao
        "$4" "$3"_"$grp"_"$srv" $grp $srv
    done
  done
}

#Recebe
#       $1 identificacao do container
#       $2 identificacao do grupo
function executaDockerMongoReplicante() {
  #executa o container
  echo "docker: rodando replicante $1"
  docker run \
      -P --name $1 \
      -d ericogr/mongodb \
      --replSet rs$2 \
      --noprealloc --smallfiles
}

#Recebe
#       $1 nome do servidor de configuração
function executaDockerMongoConfigurador() {
  #executa o container
  echo "docker: rodando configurador $1"
  docker run \
    -P --name $1 \
    -d ericogr/mongodb \
    --noprealloc --smallfiles \
    --configsvr \
    --dbpath /data/db \
    --port 27017

  executarDockerMongo $1 "db.version()"
}

#configura o roteador ou maquina que controla o shard
#Recebe
#       $1 ip dos configuradores
function executaDockerMongoRouter() {
  #substituir (espaço) por (, espaço)
  ips=$*
  ips=${ips// /:$MONGODB_PORTA,}
  ips=$ips:$MONGODB_PORTA

  #executa o container
  echo "docker: rodando router para ips $ips"
  docker run \
    -v /tmp:/mnt/tmp \
    -P --name mongos1 \
    -d ericogr/mongos \
    --port 27017 \
    --configdb $ips
}

#Recebe
#       $1 identificacao do container
#Retorno
#       o echo desta função é usado como retorno! Não use outro echo aqui!
function extraiIp() {
  #não use outro comando echo nesta função
  echo $(docker inspect $1|grep -Po '(?<="IPAddress": ")[^"]*')
}

#Recebe
#       $1 identificacao do container
#       $2 grupo de replicacao
#Variaveis
#       $IPS ips armazenados
function armazenaIPsReplicadores() {
  local ip=$(extraiIp $1)
  IPS_REP[$2]=${IPS_REP[$2]}" "$ip

  echo "IP armazenado em [$2] para [$1]: " ${IPS_REP[$2]}

  #armazena ips dos primaries
  if [ $3 -eq 1 ]
  then
    IPS_PRIMARY=$IPS_PRIMARY" "$ip
  fi
}

#Recebe
#       $1 identificacao do container
#       $2 grupo de replicacao
#Variaveis
#       $IPS ips armazenados
function armazenaIPs() {
  local ip=$(extraiIp $1)
  IPS[$2]=${IPS[$2]}" "$ip

  echo "IP armazenado em [$2] para [$1]: " ${IPS[$2]}
}

#Recebe
#       $1 identificacao do container
#       $2 comando javascript mongo
function executarDockerMongo() {
  while true; do
    echo "Executando comando em docker container: $1"
    echo " comando mongo: $2"
    docker exec $1 mongo --eval "$2">/dev/null

    execucao=$?

    if [ "$execucao" -ne "0" ]; then
      echo "Processando... aguarde nova tentativa em $TEMPO_ESPERA_SUBIDA_CONFIG_SERVERS segundos [$execucao]"
      sleep $TEMPO_ESPERA_SUBIDA_CONFIG_SERVERS
    else
      break
    fi

  done

  echo " execução do comando mongo finalizada!"
}

#Configura o ip das máquinas replicantes, substituindo o nome fornecido
#pelo docker
#Recebe
function configuraReplicantes() {
  #adiciona os ip's as máquinas
  # só é possivel adicionar depois de iniciar as máquinas e descobrir qual o
  # ip foi atribuído
  for grp in $(seq 1 $GRP_REPLICADORES)
  do
    echo "adicionando grupo " $grp
    executarDockerMongo "$PREFIXO_REPLICADORES"_"$grp"_1 "rs.initiate()"

    echo "IPs: " ${IPS_REP[$grp]}
    grupoServidorPrimary=1
    for ip in ${IPS_REP[$grp]}
    do
      if [ $grupoServidorPrimary -eq 1 ]
      then
        grupoServidorPrimary=0
        echo "setando ip " $ip:$MONGODB_PORTA " para o grupo " $grp
        executarDockerMongo "$PREFIXO_REPLICADORES"_"$grp"_1 "cfg = rs.conf(); cfg.members[0].host = '$ip:$MONGODB_PORTA'; rs.reconfig(cfg);"
      else
        echo "adicionando ip " $ip:$MONGODB_PORTA " para o grupo " $grp
        executarDockerMongo "$PREFIXO_REPLICADORES"_"$grp"_1 "rs.add('$ip:$MONGODB_PORTA');"
      fi
    done
  done
}

#Configura o ip das máquinas primary no roteador
function configuraShard() {
  #adiciona os ip's as máquinas
  # só é possivel adicionar depois de iniciar as máquinas e descobrir qual o
  # ip foi atribuído

  contar=1

  #tem somente 1 conjunto de ips no primeiro elemento!
  for ip in $IPS_PRIMARY
  do
    echo "configurado servidor para shard $contar IP " $ip
    executarDockerMongo mongos1 "sh.addShard('rs""$contar""/$ip:27017')"
    contar=$(($contar+1))
  done
}


#Recebe
#       $1 mensagem
#       $2 valor padrao
#Retorno
#       parÂmetro lido
function leituraDeDados() {
  read -p "$1"": " parametro

  if [ -z "$parametro" ]
  then
    echo "$2"
  else
    echo "$parametro"
  fi
}

function telaInicial() {
  echo
  echo "===================================================================="
  echo "Criação automatizada de máquinas para testar a replicação de dados e"
  echo "shards para Mongodb utilizando Docker"
  echo "===================================================================="
  echo
  echo "O docker criará diversos containers para a configuração especificada"
  echo "Nomenclatura:"
  echo " mongos1: ponto de entrada para as bases Mongodb (roteador)"
  echo " "$PREFIXO_REPLICADORES"_x_y: máquinas (x) que pertencem a um set de replica (y)"
  echo " "$PREFIXO_CONFIGURADORES"_1_x: máquinas (x) que pertencem a configuração dos shards"
  echo

}

#---boas vindas---
telaInicial

#---leitura dos parâmetros---
REPLICADORES=$(leituraDeDados "Digite a quantidade de replicas de instâncias para cada replica set: [$REPLICADORES])" $REPLICADORES)
GRP_REPLICADORES=$(leituraDeDados "Digite a quantidade de shards: [$GRP_REPLICADORES])" $GRP_REPLICADORES)

#---replicadores---

#executa os containers dos replicantes
seqMaquinas $GRP_REPLICADORES $REPLICADORES $PREFIXO_REPLICADORES executaDockerMongoReplicante

#executa a sequencia de máquinas e armazena os IPs
seqMaquinas $GRP_REPLICADORES $REPLICADORES $PREFIXO_REPLICADORES armazenaIPsReplicadores

#configura as maquinas que farão a replicacao de dados
configuraReplicantes

#---configuradores---

#executa os containers dos configuradores
seqMaquinas 1 $CFG_SERVERS $PREFIXO_CONFIGURADORES executaDockerMongoConfigurador

#executa a sequencia de máquinas e armazena os IPs
seqMaquinas 1 $CFG_SERVERS $PREFIXO_CONFIGURADORES armazenaIPs

#---router---

#configura as máquinas que fará a configuração dos shards
executaDockerMongoRouter ${IPS[1]}

#---shard---
configuraShard

echo "IPs primary: $IPS_PRIMARY"
echo "pronto"
