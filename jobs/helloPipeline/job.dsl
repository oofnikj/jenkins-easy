multibranchPipelineJob('helloPipeline') {
  branchSources {
    branchSource {
      source {
        git {
          id('jenkins-easy')
          remote('https://github.com/oofnikj/jenkins-easy.git')
        }
      }
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