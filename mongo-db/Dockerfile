FROM ubuntu:14.04.2

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
RUN echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list

# Instalar mongo
RUN apt-get update

RUN apt-get install -y mongodb-org

# criar diretório de dados para o mongo
RUN mkdir -p /data/db

EXPOSE 27017
ENTRYPOINT ["usr/bin/mongod"]
