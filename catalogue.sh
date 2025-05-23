#!/bin/bash

USERID=$(id -u)
PACKAGES=("$@")

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

LOGS_FOLDER="/var/log/shellscript-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
SCRIPT_RUNTIME=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME-$SCRIPT_RUNTIME.log"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER


if [ $USERID -ne 0 ]
then
    echo -e "${RED}Error: please use super user previlages to run the script ${RESET}" | tee -a $LOG_FILE
    exit 1
else
    echo -e "${GREEN}your are run the script with root user.${RESET}" | tee -a $LOG_FILE
fi

PACKAGE_INSTALLER(){
    dnf list installed $1 &>> $LOG_FILE
    if [ $? -ne 0 ]
    then
        echo -e "$1 is not installed, going to install it...${GREEN}Installing...${RESET}" | tee -a $LOG_FILE


        dnf install $1 -y &>> $LOG_FILE
        if [ $? -ne 0 ]
        then
            echo -e "${RED}$1 not installed...${RESET}" | tee -a $LOG_FILE
            exit 1
        else
            echo -e "$1 is ${GREEN}installed....${RESET}" | tee -a $LOG_FILE
        fi

    else
        echo -e "$1 already ${GREEN}installed....${RESET}" | tee -a $LOG_FILE
        exit 1
    fi
}

# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $GREEN SUCCESS $RESET" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $RED FAILURE $RESET" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf module disable nodejs -y &>> $LOG_FILE
VALIDATE $? "Disabling default nodejs package"

dnf module enable nodejs:20 -y &>> $LOG_FILE
VALIDATE $? "enabling nodejs:20 version "

PACKAGE_INSTALLER nodejs

id roboshop &>> $LOG_FILE
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> $LOG_FILE
    VALIDATE $? "robo user created"
else
    echo "robo user already created"
fi

mkdir -p /app
VALIDATE $? "checking app directory is there is not, if not create" 


curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>> $LOG_FILE
VALIDATE $? "Downloading application code"

rm -rf /app/* &>> $LOG_FILE
cd /app 
VALIDATE $? "change current directory to the /app directory"


unzip /tmp/catalogue.zip &>> $LOG_FILE
VALIDATE $? "unzipping the application code to /app directory"


npm install &>> $LOG_FILE
VALIDATE $? "installing all dependencies and libraries required to the application"

cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "adding application to the systemctl services"


systemctl daemon-reload &>> $LOG_FILE
VALIDATE $? "reloading the systemctl service"


systemctl enable catalogue &>> $LOG_FILE
VALIDATE $? "enabling our application used by systemctl commands"

systemctl start catalogue &>> $LOG_FILE
VALIDATE $? "starting services"

cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "adding repos which is required for mongo client installation"

PACKAGE_INSTALLER mongodb-mongosh &>> $LOG_FILE
VALIDATE $? "downloading and installing mongo client"


STATUS=$(mongosh --host mongodb.daws84s.site --eval 'db.getMongo().getDBNames().indexOf("catalogue")') &>> $LOG_FILE
if [ $STATUS -lt 0 ]
then
    mongosh --host mongodb.daws84s.site </app/db/master-data.js &>>$LOG_FILE
    VALIDATE $? "Loading data into MongoDB"
else
    echo -e "Data is already loaded ... $Y SKIPPING $N"
fi
