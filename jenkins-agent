pipeline {
  agent any     // run on any available agent

  options {
    newContainerPerStage()      // Useful if you want to run each stage in a different container
  }
    agent {
        kubernetes {
            cloud 'prod-k8s-us-east'
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: node-container
    image: node:18-alpine
    command:
    - cat
    tty: true
  - name: ubuntu-container
    image: ubuntu
    command:
    - sleep
    args:
    - infinity
'''
            defaultContainer 'ubuntu-container'
        }
    }
 
  stages {
    stage('S1-Any Agent') {
      steps {
        sh 'cat /etc/os-release'
        sh 'node -v'
        sh 'npm -v'
      }
    }
    
    stage('S2-Ubuntu Agent') {
      agent { 
          label 'ubuntu-20-agent'      // run on specific agent
      }
      steps {
        sh 'cat /etc/os-release'
        sh 'node -v'
        sh 'npm -v'
      }
    }

    stage ('S3-Docker Image Agent') {
        agent {
            docker {
                image 'node:18-alpine'  // below steps runs on this image (Install Docker Pipeline plugin)
                label 'ubuntu-20-agent'       // node:18-alpine image created on this agent, if we don't provide it runs on global agent
            }
        }
        steps {
            sh 'cat /etc/os-release'
            sh 'node -v'
            sh 'npm -v'
        }
    }
// Custom images for own libraries, artifacts
    stage ('S4-Dockerfile Agent') {
        agent {
            dockerfile {
                filename 'Dockerfile.cowsay'
                label 'ubuntu-20-agent'
            }
        }
        steps {
            sh 'node -v'
            sh 'npm -v'
            sh 'cowsay -f dragon This is running on Docker Container'
        }
    }
    stage ('S5-Kubernetes Agent') {
        options { retry(2) }
        steps {
            container ('node-container') {      // to run on specific container
                sh 'node -v'
                sh 'npm -v'
            }
        }
    }    
  }
}

// Dockerfile.cowsay

FROM node:18-alpine

RUN apk uodate && \
    apk add --no-cache git perl && \
    cd /tmp && \
    git clone https://github.com/jasonm/cowsay.git && \
    cd cowsay ; ./install.sh /usr/local
