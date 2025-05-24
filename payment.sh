#!/bin/bash

START_TIME=$(date +%s)
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


dnf install python3 gcc python3-devel -y &>>$LOG_FILE
VALIDATE $? "Install Python3 packages"


id roboshop &>> $LOG_FILE
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> $LOG_FILE
    VALIDATE $? "robo user created"
else
    echo "robo user already created"
fi

mkdir -p /app  &>> $LOG_FILE
VALIDATE $? "checking app directory is there is not, if not create" 

curl -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip  &>> $LOG_FILE
VALIDATE $? "Downloading application code"

rm -rf /app/* &>> $LOG_FILE
cd /app 
VALIDATE $? "change current directory to the /app directory"

unzip /tmp/payment.zip &>> $LOG_FILE
VALIDATE $? "unzipping the application code to /app directory"

pip3 install -r requirements.txt &>> $LOG_FILE
VALIDATE $? "Installing dependencies"


systemctl daemon-reload &>> $LOG_FILE
VALIDATE $? "reloading the systemctl service"

systemctl enable payment  &>> $LOG_FILE
VALIDATE $? "enabling our application used by systemctl commands"

systemctl start payment &>> $LOG_FILE
VALIDATE $? "starting services"

END_TIME=$(date +%s) &>> $LOG_FILE
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script exection completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE