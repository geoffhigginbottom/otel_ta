#! /bin/bash

IP_ADDRESS=$1

cat << EOF > /home/ubuntu/locustfile.py
from locust import HttpUser, task

class HelloWorldUser(HttpUser):
    @task
    def hello_world(self):
        self.client.get("http://$IP_ADDRESS")
EOF

