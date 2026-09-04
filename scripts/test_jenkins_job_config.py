import tempfile
import unittest
from pathlib import Path

from jenkins_job_config import render, verify


GITHUB_XML = """<?xml version='1.0' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
  <description>existing</description>
  <sources><data><jenkins.branch.BranchSource>
    <source class="org.jenkinsci.plugins.github_branch_source.GitHubSCMSource">
      <id>old-source</id>
      <credentialsId>github-credentials-id</credentialsId>
      <repoOwner>old-owner</repoOwner>
      <repository>old-repository</repository>
    </source>
  </jenkins.branch.BranchSource></data></sources>
  <factory><org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory>
    <scriptPath>Jenkinsfile</scriptPath>
  </org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory></factory>
  <triggers><com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger /></triggers>
  <disabled>false</disabled>
</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
"""

GIT_XML = """<?xml version='1.0' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
  <sources><data><jenkins.branch.BranchSource><source>
    <jenkins.plugins.git.GitSCMSource>
      <id>old-source</id>
      <remote>https://github.com/example/old.git</remote>
      <credentialsId>old-credential</credentialsId>
    </jenkins.plugins.git.GitSCMSource>
  </source></jenkins.branch.BranchSource></data></sources>
  <factory><org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory>
    <scriptPath>Otherfile</scriptPath>
  </org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory></factory>
</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
"""


class JenkinsJobConfigTest(unittest.TestCase):
    repository = "https://github.com/ditasetyakurniawan-droid/zabisa-super-app.git"
    credentials = "github-credentials-id"
    script_path = "Jenkinsfile"

    def render_fixture(self, xml: str) -> tuple[Path, tempfile.TemporaryDirectory]:
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        source = root / "source.xml"
        output = root / "output.xml"
        source.write_text(xml, encoding="utf-8")
        render(source, output, self.repository, self.credentials, self.script_path)
        return output, temporary

    def test_renders_actual_github_scm_source_shape(self):
        output, temporary = self.render_fixture(GITHUB_XML)
        try:
            self.assertEqual(
                verify(output, self.repository, self.credentials, self.script_path),
                "github",
            )
            content = output.read_text(encoding="utf-8")
            self.assertIn("<repoOwner>ditasetyakurniawan-droid</repoOwner>", content)
            self.assertIn("<repository>zabisa-super-app</repository>", content)
            self.assertIn("<triggers />", content)
            self.assertIn("<disabled>true</disabled>", content)
        finally:
            temporary.cleanup()

    def test_keeps_git_scm_source_compatibility(self):
        output, temporary = self.render_fixture(GIT_XML)
        try:
            self.assertEqual(
                verify(output, self.repository, self.credentials, self.script_path),
                "git",
            )
            self.assertIn(self.repository, output.read_text(encoding="utf-8"))
        finally:
            temporary.cleanup()

    def test_rejects_config_without_supported_scm_source(self):
        broken = GITHUB_XML.replace(
            "class=\"org.jenkinsci.plugins.github_branch_source.GitHubSCMSource\"",
            "class=\"unsupported.Source\"",
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.xml"
            output = root / "output.xml"
            source.write_text(broken, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "exactly one supported"):
                render(
                    source,
                    output,
                    self.repository,
                    self.credentials,
                    self.script_path,
                )


if __name__ == "__main__":
    unittest.main()
