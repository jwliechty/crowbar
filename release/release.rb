#PROJECTS = %w(ascent-upload-client MzConvertService ascent-cpp-compute ascent-quartermaster ascent-web compute-runner qa-rules-core)
PROJECTS = %w(ascent-upload-client MzConvertService ascent-cpp-compute ascent-quartermaster ascent-web compute-runner qa-rules-core)

class ProjectRelease
  RELEASE_PREFIX = 'release-'

  def initialize(name)
    @project = name
  end

  def release
    clone_repo_if_dne
    Dir.chdir(@project) do
      prepare_repo
      ask_for_release_version
      ensure_release_dne
      create_release
      update_version_files
      push release_branch
      pull_into_develop_and_push
      checkout release_branch
      puts "\n\tDone"
    end
  end

  private
  def clone_repo_if_dne
    puts "\nSetting up #{@project}"
    clone_repo unless Dir.exists?(@project)
  end

  def clone_repo
    puts "\n\tCloning #{@project}"
    run "git clone git@github.com:indigo-biosystems/#{@project}.git"
  end

  def prepare_repo
    refresh_branches
    pull_origin
    fetch_tags
    pull_master_into_develop
    setup_git_flow
  end

  def refresh_branches
    checkout 'master'
    checkout 'develop'
    delete 'master'
    checkout 'master'
    delete 'develop'
    checkout 'develop'
  end

  def pull_origin
    puts "\n\tFetch origin"
    run 'git pull origin'
  end

  def fetch_tags
    puts "\n\tFetch tags"
    run 'git fetch origin --tags'
  end

  def checkout(branch)
    puts "\n\tCheckout #{branch}"
    run "git checkout #{branch}"
  end

  def delete(branch)
    puts "\n\tDelete #{branch}"
    run "git branch -d #{branch}"
  end

  def pull_master_into_develop
    puts "\n\tPulling master into develop"
    run 'git checkout develop'
    run 'git pull origin master'
  end

  def setup_git_flow
    puts "\n\tSetup GitFlow"
    input_file = '../git_flow_input.txt'
    File.open(input_file, 'w') { |file| file.write git_flow_init_input }
    run "git flow init -f < #{input_file}"
    File.delete input_file
  end

  def ask_for_release_version
    suggestion = next_release_version
    print "[QUESTION - #{@project}] Next release without prefix [#{suggestion}] "
    version = STDIN.gets.chomp.strip
    @release_version = version.empty? ? suggestion : version
  end

  def next_release_version
    tags = run('git tag').split /\s+/
    if tags.empty?
      TagVersion.new('').version_number
    else
      tag = tags.map{|tag| TagVersion.new tag}.sort.last
      tag.defaulted? ? tag.version_number : tag.increment_minor.version_number
    end
  end

  def ensure_release_dne
    %x([ $(git branch -a | egrep '(remotes/origin/#{release_branch}|[[:blank:]]#{release_branch})$' | wc -l) -eq 0 ])
    raise "release branch #{release_branch} already exists" unless $?.success?
  end

  def create_release
    puts "\n\tCreate Release"
    run "git flow release start #{@release_version}"
  end

  def update_version_files
    if File.exists?('update_version.sh')
      puts "\n\tUpdating internal files"
      run "./update_version.sh #{@release_version}"
    end
  end

  def push_release
    puts "\n\tPush Release"
    cmd = "git flow release finish -m 'create_version_#{@release_version}' #{@release_version}"
    puts run cmd
  end

  def pull_into_develop_and_push
    puts "\n\tPulling release into develop and pushing"
    run 'git checkout -q develop'
    run "git pull origin #{release_branch}"
    run 'git push origin develop'
  end

  def release_branch
    "#{RELEASE_PREFIX}#{@release_version}"
  end

  def push(name)
    puts "\n\tPushing #{name}"
    run "git checkout -q #{name}"
    run "git push origin #{name}"
  end

  def run(cmd)
    output = %x(#{cmd})
    unless $?.success?
      puts output
      raise "Command failed with status code #{$?.exitstatus}: #{cmd}"
    end
    output
  end

  def git_flow_init_input
<<END
master
develop
f-
#{RELEASE_PREFIX}
hotfix-
support-
v

END
  end
end

class TagVersion
  attr_reader :major, :minor, :patch

  def initialize(tag)
    md = /(\d+)\.(\d+)\.(\d+)/.match tag
    if md
      @major = md[1].to_i
      @minor = md[2].to_i
      @patch = md[3].to_i
      @defaulted = false
    else
      @major = 1
      @minor = 0
      @patch = 0
      @defaulted = true
    end
  end

  def <=>(o)
    if major < o.major
      -1
    elsif major > o.major
      1
    elsif minor < o.minor
      -1
    elsif minor > o.minor
      1
    elsif patch < o.patch
      -1
    elsif patch > o.patch
      1
    else
      0
    end
  end

  def defaulted?
    @defaulted
  end

  def major_minor_version
    "#{@major}.#{@minor}"
  end

  def increment_minor
    @minor += 1
    @patch = 0
    self
  end

  def version_number
    "#@major.#@minor.#@patch"
  end
end

PROJECTS.each do |project|
  ProjectRelease.new(project).release
end
