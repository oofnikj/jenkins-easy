multibranchPipelineJob('helloPipeline') {
  branchSources {
    git {
      id('jenkins-easy')
      remote('https://github.com/oofnikj/jenkins-easy.git')
    }
    factory {
      workflowBranchProjectFactory {
        scriptPath('jobs/helloPipeline/Jenkinsfile')
      }
    }
  }
}