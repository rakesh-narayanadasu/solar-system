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
    }
    post {
        always {
            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'dependency-check-jenkins.html', reportName: 'Dependency Check HTML Report', reportTitles: '', useWrapperFileDirectly: true])
            junit allowEmptyResults: true, testResults: 'dependency-check-junit.xml'
            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Code Coverage HTML Report', reportTitles: '', useWrapperFileDirectly: true])
        }
    }
}

