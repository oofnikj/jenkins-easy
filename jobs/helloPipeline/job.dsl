multibranchPipelineJob('helloPipeline') {
  branchSources {
    git {
      id('jenkins-easy')
      remote('https://github.com/oofnikj/jenkins-easy.git')
    }
    branchSources {
      branchSource {
        strategy {
          allBranchesSame {
            props {
              suppressAutomaticTriggering()
            }
          }
        }
      }
    }
    factory {
      workflowBranchProjectFactory {
        scriptPath('jobs/helloPipeline/Jenkinsfile')
      }
    }
  }
}