require "minitest/autorun"
require "open3"
require "tmpdir"

class SyncBaseTest < Minitest::Test
  SCRIPT = File.expand_path("../script/codex/sync-base.sh", __dir__)

  def test_refuses_to_run_on_master
    with_repository do |root, repository|
      before = git(repository, "rev-parse", "HEAD")

      output, status = run_sync(repository)

      refute status.success?
      assert_match(/refusing to synchronize while on base branch master/i, output)
      assert_equal before, git(repository, "rev-parse", "HEAD")
    end
  end

  def test_refuses_to_run_with_dirty_issue_branch
    with_repository do |_root, repository|
      git(repository, "switch", "-c", "codex/issue-test")
      File.write(File.join(repository, "tracked.txt"), "uncommitted\n")

      output, status = run_sync(repository)

      refute status.success?
      assert_match(/working tree is not clean/i, output)
    end
  end

  def test_fast_forwards_issue_branch_to_current_remote_base
    with_repository do |root, repository|
      git(repository, "switch", "-c", "codex/issue-test")
      publisher = publish_base_update(root)

      output, status = run_sync(repository)

      assert status.success?, output
      assert_match(/fast-forwarding/i, output)
      assert_equal "base update\n", File.read(File.join(publisher, "tracked.txt"))
      assert_equal "base update\n", File.read(File.join(repository, "tracked.txt"))
      assert_remote_base_is_ancestor(repository)
    end
  end

  def test_merges_divergent_issue_branch_without_rebasing
    with_repository do |root, repository|
      git(repository, "switch", "-c", "codex/issue-test")
      File.write(File.join(repository, "issue.txt"), "issue work\n")
      git(repository, "add", "issue.txt")
      git(repository, "commit", "-m", "issue work")

      publish_base_update(root)
      output, status = run_sync(repository)

      assert status.success?, output
      assert_match(/merged origin\/master/i, output)
      assert_equal "issue work\n", File.read(File.join(repository, "issue.txt"))
      assert_equal "base update\n", File.read(File.join(repository, "tracked.txt"))
      assert_remote_base_is_ancestor(repository)
    end
  end

  def test_aborts_conflicting_merge_and_restores_issue_branch
    with_repository do |root, repository|
      git(repository, "switch", "-c", "codex/issue-test")
      File.write(File.join(repository, "tracked.txt"), "issue change\n")
      git(repository, "add", "tracked.txt")
      git(repository, "commit", "-m", "issue change")
      before = git(repository, "rev-parse", "HEAD")

      publish_base_update(root, contents: "base change\n")
      output, status = run_sync(repository)

      refute status.success?
      assert_match(/merge conflict.*aborted/i, output)
      assert_equal before, git(repository, "rev-parse", "HEAD")
      assert_equal "", git(repository, "status", "--porcelain")
      refute File.exist?(File.join(repository, ".git", "MERGE_HEAD"))
    end
  end

  private

  def with_repository
    Dir.mktmpdir("sync-base-test") do |root|
      origin = File.join(root, "origin.git")
      repository = File.join(root, "repository")
      git(root, "init", "--bare", origin)
      git(root, "init", repository)
      configure_identity(repository)
      File.write(File.join(repository, "tracked.txt"), "base\n")
      git(repository, "add", "tracked.txt")
      git(repository, "commit", "-m", "initial")
      git(repository, "branch", "-M", "master")
      git(repository, "remote", "add", "origin", origin)
      git(repository, "push", "-u", "origin", "master")
      yield root, repository
    end
  end

  def publish_base_update(root, contents: "base update\n")
    origin = File.join(root, "origin.git")
    publisher = File.join(root, "publisher")
    git(root, "clone", origin, publisher)
    configure_identity(publisher)
    File.write(File.join(publisher, "tracked.txt"), contents)
    git(publisher, "add", "tracked.txt")
    git(publisher, "commit", "-m", "base update")
    git(publisher, "push", "origin", "master")
    publisher
  end

  def configure_identity(repository)
    git(repository, "config", "user.name", "Sync Base Test")
    git(repository, "config", "user.email", "sync-base-test@example.invalid")
  end

  def run_sync(repository, *args)
    stdout, stderr, status = Open3.capture3({}, SCRIPT, *args, chdir: repository)
    [stdout + stderr, status]
  end

  def git(repository, *args)
    stdout, stderr, status = Open3.capture3(git_environment, "git", *args, chdir: repository)
    raise "git #{args.join(" ")} failed: #{stdout}#{stderr}" unless status.success?

    stdout
  end

  def assert_remote_base_is_ancestor(repository)
    _stdout, _stderr, status = Open3.capture3(git_environment, "git", "merge-base", "--is-ancestor", "refs/remotes/origin/master", "HEAD", chdir: repository)
    assert status.success?, "origin/master is not an ancestor of HEAD"
  end

  def git_environment
    {
      "GIT_AUTHOR_NAME" => "Sync Base Test",
      "GIT_AUTHOR_EMAIL" => "sync-base-test@example.invalid",
      "GIT_COMMITTER_NAME" => "Sync Base Test",
      "GIT_COMMITTER_EMAIL" => "sync-base-test@example.invalid"
    }
  end
end
