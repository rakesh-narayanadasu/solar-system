pipeline {
    agent any

    tools {
        nodejs 'node-22-6-0'
    }

    options {
        timestamps()
        disableConcurrentBuilds abortPrevious: true
        // disableResume()
        // disableRestartFromStage()
        // timeout(activity: true, time: 45)
    }    

    environment {
        MONGO_URI = "mongodb+srv://supercluster.d83jj.mongodb.net/superData"
        MONGO_DB_CREDS = credentials('mongo-creds')

        MONGO_USERNAME = credentials('mongo_username')
        MONGO_PASSWORD = credentials('mongo_password')

        SONAR_SCANNER_HOME = tool 'sonar-scanner-6-1-0'; // SonarQube plugin version 6.1.0

        GITEA_TOKEN = credentials('gitea_api_token')    // Generate an access token Settings -> Applications 
    }    

    stages {
        stage ('Install Dependencies') {
            steps {
                sh '''
                    npm install --no-audit
                '''
            }
        }

        stage ('Dependency Check') {
            parallel {
                stage ('NPM Dependency Audit') {
                    steps {
                        sh '''
                            npm audit --audit-level=critical
                        '''
                    }
                }             
                stage('OWASP Dependency Check') {
                    steps {
                        dependencyCheck additionalArguments: '''
                            --scan './'
                            --out './'
                            --format 'ALL'
                            --disableRetireJS
                            --disableYarnAudit
                            --prettyPrint
                        ''', odcInstallation: 'OWASP-Dep-Check-12-1-0'      // OWASP plugin version 12.1.0

                        dependencyCheckPublisher failedTotalCritical: 1, pattern: 'dependency-check-report.xml', stopBuild: true             
                    }
                }            
            }
        }

        stage ('Unit Tests') {
            options {
              retry(2)
            }
            steps {
                sh '''
                    echo "Mongo Creds - $MONGO_DB_CREDS"
                    echo "Username - $MONGO_DB_CREDS_USR"
                    echo "Password - $MONGO_DB_CREDS_PSW"

                    npm test
                '''
                junit allowEmptyResults: true, testResults: 'test-results.xml'
            }
        } 

        stage ('Code Coverage') {
            steps {   
                catchError(buildResult: 'SUCCESS', message: 'Oops! it will be fixed in future release', stageResult: 'UNSTABLE') {  // Prevent pipeline from failure
                    sh 'npm run coverage'
                }                
            }
        }  

        // stage ('SAST - SonarQube') {
        //     steps {
        //         sh 'echo $SONAR_SCANNER_HOME'
        //         sh '''
        //             $SONAR_SCANNER_HOME/bin/sonar-scanner \
        //                 -Dsonar.host.url=http://54.210.121.126:9000 \
        //                 -Dsonar.token=sqp_09ed7d3bbd6d590eadb26f6e3641ec4b1876d44b \
        //                 -Dsonar.projectKey=solar-system \
        //                 -Dsonar.sources=app.js \
        //                 -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
        //         '''
        //     }
        // }

        stage ('SAST - SonarQube') {
            steps {
                timeout(time: 60, unit: 'SECONDS') {
                    withSonarQubeEnv('sonar-qube-server') {      // Configure SonarQuber server in System with sonarqube URL and Token
                        sh 'echo $SONAR_SCANNER_HOME'
                        sh '''
                            $SONAR_SCANNER_HOME/bin/sonar-scanner \
                                -Dsonar.projectKey=solar-system \
                                -Dsonar.sources=app.js \
                                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                        '''
                    }
                    waitForQualityGate abortPipeline: true
                }    
            }
        }

        stage ('Build Docker Image') {
            steps {
                sh 'printenv'

                sh 'docker build -t rakeshn88/solar-system:$GIT_COMMIT .'
            }
        }

        stage ('Trivy Vulnerability Scanning') {
            steps {
                sh '''
                    trivy image rakeshn88/solar-system:$GIT_COMMIT \
                        --severity LOW,MEDIUM,HIGH \
                        --exit-code 0 \
                        --quiet \
                        --format json -o trivy-image-MEDIUM-results.json

                    trivy image rakeshn88/solar-system:$GIT_COMMIT \
                        --severity CRITICAL \
                        --exit-code 0 \
                        --quiet \
                        --format json -o trivy-image-CRITICAL-results.json
                '''
            }
            post {
                always {
                    sh '''
                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-image-MEDIUM-results.html trivy-image-MEDIUM-results.json

                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/junit.tpl" \
                            --output trivy-image-MEDIUM-results.xml trivy-image-MEDIUM-results.json

                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-image-CRITICAL-results.html trivy-image-CRITICAL-results.json

                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/junit.tpl" \
                            --output trivy-image-CRITICAL-results.xml trivy-image-CRITICAL-results.json                                                           
                    '''
                }
            }
        }

        stage ('Push Docker Image') {
            steps {
                withDockerRegistry(credentialsId: 'dockerhub-creds', url: "") {
                    sh '''
                        docker push rakeshn88/solar-system:$GIT_COMMIT
                    '''
                }
            }
        }

        stage ('Deploy To AWS EC2') {
            when {
                branch 'feature/*'
            }
            steps {
                sshagent(['aws-dev-deploy-ec2']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ubuntu@32.192.229.171 "
                            if docker ps -a | grep -q "solar-system";
                            then
                                echo "Container found Stopping..."
                                    docker stop "solar-system" && docker rm "solar-system"
                                echo "Container Stopped and Removed."
                            fi
                                docker run --name solar-system \
                                    -e MONGO_URI=$MONGO_URI \
                                    -e MONGO_USERNAME=$MONGO_USERNAME \
                                    -e MONGO_PASSWORD=$MONGO_PASSWORD \
                                    -p 4000:3000 -d rakeshn88/solar-system:$GIT_COMMIT
                        "
                    '''
                }
            }
        }

        stage ('Integration Testing AWS EC2') {
            when {
                branch 'feature/*'
            }            
            steps {
                sh 'printenv | grep -i branch'
                withAWS(credentials: 'aws-ec2-s3-lambda', region: 'us-east-1') {
                    sh '''
                        bash integration-testing-ec2.sh
                    '''
                }
            }
        }

        stage ('K8S Update Image Tag') {
            when {
                branch 'PR*'
            }
            steps {
                sh 'git clone -b main http://32.192.229.171:3000/InfraAutomation/solar-system-gitops-argocd-gitea'
                dir('solar-system-gitops-argocd-gitea/kubernetes') {
                    sh '''
                        ### Replace Docker Tag ###
                        git checkout main
                        git checkout -b feature-$BUILD_ID
                        sed -i "s#rakeshn88.*#rakeshn88/solar-system:$GIT_COMMIT#g" deployment.yml
                        cat deployment.yml

                        ### Commit and Push to Feature Branch ###
                        git config --global user.email "jenkins@demo.com"
                        git remote set-url origin http://$GITEA_TOKEN@32.192.229.171:3000/InfraAutomation/solar-system-gitops-argocd-gitea
                        git add .
                        git commit -am "Updated Docker Image"
                        git push -u origin feature-$BUILD_ID
                    '''
                }
            }
        }

        stage ('K8S - Raise PR') {
            when {
                branch 'PR*'
            }
            steps {
                withCredentials([string(credentialsId: 'gitea_api_token', variable: 'GITEA_TOKEN')]) {
                    sh '''
                        curl -X POST \
                        "http://32.192.229.171:3000/api/v1/repos/InfraAutomation/solar-system-gitops-argocd-gitea/pulls" \
                        -H "accept: application/json" \
                        -H "Authorization: token $GITEA_TOKEN" \
                        -H "Content-Type: application/json" \
                        -d '{
                                "assignee": "rakesh",
                                "assignees": ["rakesh"],
                                "base": "main",
                                "body": "Updated docker image in deployment.yml manifest",
                                "head": "feature-'$BUILD_ID'",
                                "title": "Updated Docker Image"
                            }'
                    '''
                }
            }
        }  

        stage ('App Deployed?') {
            when {
                branch 'PR*'
            }
            steps {
                timeout(time: 1, unit: 'DAYS') {
                    input message: 'Is the PR Merged and ArgoCD Synced?', ok: 'Yes! PR is Merged and ArgoCD Application is Synced'
                }
            }
        }  

        stage ('DAST - OWASP ZAP') {
            when {
                branch 'PR*'
            }
            steps {
                sh '''
                    ### Replace below with kubernetes http://IP_Address:3000/api-docs/
                    chmod 777 $(pwd)
                    docker run -v $(pwd):/zap/wrk/:rw ghcr.io/zaproxy/zaproxy zap-api-scan.py \
                        -t http://32.192.229.171:4000/api-docs/ \
                        -f openapi \
                        -r zap_report.html \
                        -w zap_report.md \
                        -J zap_json_report.json \
                        -x zap_xml_report.xml \
                        -c zap_ignore_rules     # create zap_ignore_rules file and add ID IGNORE <endpoint> eg: 100001	IGNORE	http://32.192.229.171:4000
                '''
            }
        }

        stage ('Upload - AWS S3') {
            when {
                branch 'PR*'
            }
            steps {
                withAWS(credentials: 'aws-ec2-s3-lambda', region: 'us-east-1') {
                    sh '''
                        ls -lrt
                        mkdir reports-$BUILD_ID
                        cp -rf coverage/ reports-$BUILD_ID/
                        cp dependency*.* test-results.xml trivy*.* zap*.* reports-$BUILD_ID/
                        ls -lrt reports-$BUILD_ID/
                    '''
                    s3Upload(
                        file:"reports-$BUILD_ID",
                        bucket:'solar-system-demo-jenkins-project',
                        path:"jenkins-$BUILD_ID/"
                    )
                }
            }
        }  

        stage ('Deploy to Prod?') {
            when {
                branch 'main'
            }
            steps {
                timeout(time: 1, unit: 'DAYS') {
                    input message: 'Deploy to Production?', ok: 'Yes! Lets deploy on Production', submitter: 'admin'
                }
            }
        }    
    }
    post {
        always {
            // Removing the repo directory to avoid error while cloning
            script {   
                if (fileExists('solar-system-gitops-argocd-gitea')) {
                    sh 'rm -rf solar-system-gitops-argocd-gitea'
                }
            }

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'dependency-check-jenkins.html', reportName: 'Dependency Check HTML Report', reportTitles: '', useWrapperFileDirectly: true])

            junit allowEmptyResults: true, testResults: 'dependency-check-junit.xml'
            
            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Code Coverage HTML Report', reportTitles: '', useWrapperFileDirectly: true])

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-image-MEDIUM-results.html', reportName: 'Trivy Image Medium Vul Report', reportTitles: '', useWrapperFileDirectly: true]) 

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-image-CRITICAL-results.html', reportName: 'Trivy Image Critical Vul Report', reportTitles: '', useWrapperFileDirectly: true])

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'zap_report.html', reportName: 'DAST OWASP ZAP Report', reportTitles: '', useWrapperFileDirectly: true])

            junit allowEmptyResults: true, testResults: 'trivy-image-MEDIUM-results.xml'

            junit allowEmptyResults: true, testResults: 'trivy-image-CRITICAL-results.xml'
        }
    }
}

