# docker-mongodb-replica-shard-test
O objetivo deste projeto é fornecer um ambiente para testar um cluster de máquinas
com replicação e sharding de Mongodb 3. A primeira execução cria todo o ambiente com
containers utilizando uma nomenclatura padrão. Para executar novamente, será
preciso antes finalizar os containers criados anteriormente por este script.

##Passos para testar o shard com replicação do mongodb

Pré-requisitos
 -OS Linux
 -Docker 1.5 ou superior

1. Executar o build das imagens docker:
 ```
 #./build.sh
 ```

2. Executar a criação e configuração das máquinas:
 -Na configuração padrão, serão criados 2 shards. Cada shard é composto por um
  conjunto de replicação de 3 máquinas.

  -Obs: durante a criação das máquinas, alguns scripts serão executados pelo
        mongo, mas muitas vezes a instância ainda não estará pronta. Desta
        forma, o script será executado novamente depois de alguns segundos.
        Isso pode levar alguns minutos, então, aguarde até que o processo chegue
        ao fim.

3. Descubra o ip da máquina que faz o roteamento
  ```
  #docker inspect mongos1|grep -i ipaddress
  ```

  -Obs: Será nesta máquina que devemos apontar a conexão para o banco de dados
        mongo na aplicação.

4. Criar banco de dados e coleção
 -Os comandos abaixo servem como referência. Devem ser executados conectando a
  ao container mongos1. Você pode utilizar um cliente como o Robomongo para
  testar.

  -Para verificar o status do shard
    ```
    sh.status()
    ```

  -Para criar um banco de dados dbshard1 e habilitar o shard:
    ```
    use dbshard1
    sh.enableSharding("dbshard1")
    ```

  -Para criar uma coleção de dados chamada pessoas e habilitar o shard baseado
   no campo nome:
    ```
    db.createCollection("pessoas")
    sh.shardCollection("dbshard1.pessoas", { "nome": 1 })
    ```

5. Importar dados para a coleção pessoas
 -Na raiz do projeto temos o arquivo pessoas.json com um cojunto de dados para
  testar. Coloque este arquivo na pasta /tmp de seu host para que fique disponível
  na pasta /mnt/tmp do container mongos1. Execute a importação:
  
  ```
  #docker \
    exec mongos1 mongoimport \
      --db dbshard1 \
      --collection pessoas \
      --type json \
      --jsonArray \
      --file /mnt/tmp/pessoas.json
  ```

6. Verifique como estão distribuidos os dados
 -Na máquina mongos1 execute:
   ```
   sh.status()
   ```

Exemplo de saída:

```
--- Sharding Status ---
  sharding version: {
	"_id" : 1,
	"minCompatibleVersion" : 5,
	"currentVersion" : 6,
	"clusterId" : ObjectId("55369699a0dd158b580cf6cb")
}
  shards:
	{  "_id" : "rs1",  "host" : "rs1/172.17.0.132:27017,172.17.0.133:27017,172.17.0.134:27017" }
	{  "_id" : "rs2",  "host" : "rs2/172.17.0.135:27017,172.17.0.136:27017,172.17.0.137:27017" }
  databases:
	{  "_id" : "admin",  "partitioned" : false,  "primary" : "config" }
	{  "_id" : "db",  "partitioned" : false,  "primary" : "rs2" }
	{  "_id" : "test",  "partitioned" : false,  "primary" : "rs2" }
	{  "_id" : "dbshard1",  "partitioned" : true,  "primary" : "rs2" }
		dbshard1.pessoas
			shard key: { "nome" : 1 }
			chunks:
				rs1	1
				rs2	8
			{ "nome" : { $minKey : 1 } } -->> { "nome" : "Aaron" } on : rs1 Timestamp(2000, 0)
			{ "nome" : "Aaron" } -->> { "nome" : "Dayna" } on : rs2 Timestamp(2000, 1)
			{ "nome" : "Dayna" } -->> { "nome" : "Fernando" } on : rs2 Timestamp(1000, 3)
			{ "nome" : "Fernando" } -->> { "nome" : "Jayden" } on : rs2 Timestamp(1000, 4)
			{ "nome" : "Jayden" } -->> { "nome" : "Leonardo" } on : rs2 Timestamp(1000, 5)
			{ "nome" : "Leonardo" } -->> { "nome" : "Mose" } on : rs2 Timestamp(1000, 6)
			{ "nome" : "Mose" } -->> { "nome" : "Rudolph" } on : rs2 Timestamp(1000, 7)
			{ "nome" : "Rudolph" } -->> { "nome" : "Wava" } on : rs2 Timestamp(1000, 8)
			{ "nome" : "Wava" } -->> { "nome" : { $maxKey : 1 } } on : rs2 Timestamp(1000, 9)

```
