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
                            --prettyPrint
                        ''', odcInstallation: 'OWASP-Dep-Check-12-1-0'

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
                catchError(buildResult: 'SUCCESS', message: 'Oops! it will be fixed in future release', stageResult: 'UNSTABLE') {
                    sh 'npm run coverage'
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

