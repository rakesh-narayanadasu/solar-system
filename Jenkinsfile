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
                        ssh -o StrictHostKeyChecking=no ubuntu@98.94.48.65 "
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
    }
    post {
        always {
            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'dependency-check-jenkins.html', reportName: 'Dependency Check HTML Report', reportTitles: '', useWrapperFileDirectly: true])

            junit allowEmptyResults: true, testResults: 'dependency-check-junit.xml'
            
            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Code Coverage HTML Report', reportTitles: '', useWrapperFileDirectly: true])

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-image-MEDIUM-results.html', reportName: 'Trivy Image Medium Vul Report', reportTitles: '', useWrapperFileDirectly: true]) 

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-image-CRITICAL-results.html', reportName: 'Trivy Image Critical Vul Report', reportTitles: '', useWrapperFileDirectly: true])

            junit allowEmptyResults: true, testResults: 'trivy-image-MEDIUM-results.xml'

            junit allowEmptyResults: true, testResults: 'trivy-image-CRITICAL-results.xml'
        }
    }
}

