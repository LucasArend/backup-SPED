#!/bin/sh
#---------------------------------------------------------------------#
#  SECAO DE INFORMATICA DO 3ºBECmb                                    #
#  Criação: 19/08/2019                                                #
#  Realiza o Backup automático do SPED, e envia para armazenamento    #
# exerno via samba.                                                   #
#  local do crontab: /etc/crontab                                     #
#                                                       Sd Arend v1.0 #
#---------------------------------------------------------------------#

#---------------------------------------------------------#
# Declaração das Variáveis
#---------------------------------------------------------#
Data=$(date +%d%m%Y)
DataHora=$(date +%Y-%m-%d--%H-%M)
Dias=7
PastaWeb=/var/lib/tomcat7/webapps
PastaBackup=/var/backups/BackupSPED/$(date +%Y-%m-%d)
PastaLog=/root/Desktop/BackupSPED/BackupSPED/logs
HostName=$(hostname)
LOG=$PastaLog/backup-$DataHora.log

#---------------------------------------------------------#
# Função para criação de diretórios
#---------------------------------------------------------#
CheckDir() {
  if [ ! -d "$1" ]; then
    mkdir -p $1
    if [ "$?" != "0" ]; then
      echo "A Pasta -> $1 não pôde ser criada! Encerrando Backup..." >> $LOG
      exit 1
    fi
        echo "Pasta -> $1 criada com sucesso!" >> $LOG
  fi
}

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Iniciando Processo de Backup do servidor SPED:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG

# Verifica se existe a pasta para Log, caso contrário ela será criada
CheckDir "$PastaLog"

# Verifica se existe a pasta para Backups, caso contrário ela será criada
CheckDir "$PastaBackup"

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Iniciando Processo de Backup:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG

#CheckDir "$PastaBackup/$Data"

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Efetuando Backup da Aplicação Web:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG

/etc/init.d/tomcat7 stop
cd $PastaWeb
cp sped.war $PastaBackup
if [ "$?" != "0" ]; then
  echo "O Backup da Aplicação Web não pôde ser gerado!" >> $LOG
else
  echo "Backup da Aplicação Web realizado com sucesso." >> $LOG
fi

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Efetuando Backup da Base LDAP:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG
/etc/init.d/slapd stop
slapcat -l $PastaBackup/backup_ldap.ldif
if [ $? -eq 0 ]; then
  echo "O Backup da Base LDAP não pôde ser gerado!" >> $LOG
else
  echo "Backup da Base LDAP realizado com sucesso." >> $LOG
fi
/etc/init.d/slapd start

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Efetuando Backup do Banco de Dados:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG
su postgres -c "pg_dump -E UTF8 -v spedDB > /var/lib/postgresql/backup_spedDB.sql" 2>> $LOG
if [ $? -ne 0 ]; then
  echo "O Backup do Banco de Dados não pôde ser gerado!" >> $LOG
else
  mv /var/lib/postgresql/backup_spedDB.sql $PastaBackup/backup_spedDB.sql
  echo "Backup do Banco de Dados realizado com sucesso." >> $LOG
fi

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Definindo Permissões de Leitura e Escrita em $PastaBackup:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG
chown -R sped $PastaBackup
chmod 0755 $PastaBackup

/etc/init.d/tomcat7 start #do backup normal


echo "Horario OK! :)"  >> $LOG

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Apagando arquivos de backup do SPED com mais de $Dias dias:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG
find $PastaBackup -type d -mtime +$Dias -exec rm -rf {} \; >> $LOG

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Apagando arquivos de log com mais de $Dias dias:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG
find $PastaLog -type f -mtime +$Dias -exec rm -f {} \; >> $LOG

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Sincronizando arquivos de BACKUP com TeraStation 1:" >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo $PastaBackup
sleep 2
cd /root/Desktop/BackupSPED
smbclient *****/***** --user=admin --pass ******* -c "recurse; prompt; cd BK_SPED; mput $(date +%Y-%m-%d)*" >> $LOG

sleep 10

echo " " >> $LOG
echo "#----------------------------------------------------#" >> $LOG
echo "Processo de Backup finalizado" >> $LOG
echo "#----------------------------------------------------#" >> $LOG
