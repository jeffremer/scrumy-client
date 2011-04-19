require 'scrumy'
require 'yaml'

describe Scrumy::Client do
  before(:all) do
    credentials = File.open( 'scrumy_credentials.yml' ) { |yf| YAML::load( yf ) }
    @client = Scrumy::Client.new(credentials['project'], credentials['password'])            
  end
  
  describe '#scumy' do
    it "fetches the Scrumy object" do
      scrumy = @client.scrumy
      scrumy.should be_an_instance_of Scrumy::Models::Scrumy
    end
  end
  
  describe '#sprint(id=:current)' do
    it "fetches a full current sprint" do
      sprint = @client.sprint(:current)
      sprint.stories.size.should > 0
      sprint.should be_an_instance_of Scrumy::Models::Sprint
    end
  end

  describe '#sprint(id)' do
    it "fetches a sprint by ID" do
      sprints = @client.sprints
      sprint = @client.sprint(sprints[1].id)
      sprint.should be_an_instance_of Scrumy::Models::Sprint
    end
  end
  
  describe '#sprints' do
    it "fetches a list of sprints" do
      @client.sprints.each do |sprint|
        sprint.should be_an_instance_of Scrumy::Models::Sprint
      end
    end
  end
  
  describe '#stories' do
    it "fetches a list of stories based on a sprint" do
      sprints = @client.sprints
      sprints[1].stories.each do |story|
        story.should be_an_instance_of Scrumy::Models::Story
      end
    end
  end
  
  describe '#tasks' do
    it "fetches a list of tasks based on a story" do
      @client.sprints[1].stories[1].tasks do |task|
        task.should be_an_instance_of Scrumy::Models::Task
        task.scrumer.should be_an_instance_of Scrumy::Models::Scrumer
      end
    end
  end
  
  describe '#scrumers' do
    it "fetches a list of scrumers by scrumy" do
      @client.scrumers.each do |scrumer|
        scrumer.should be_an_instance_of Scrumy::Models::Scrumer
      end
    end
  end
  
  describe '#scrumer' do
    it "fetches a scrumer by name" do
      scrumer = @client.sprints[1].stories[1].tasks[1].scrumer
      scrumer2 = @client.scrumer(scrumer.name)
      scrumer.name.should == scrumer2.name
      scrumer.color.should == scrumer2.color
    end
  end
  
  describe '#snapshots' do
    it "fetches a list of snapshots" do
      snapshots = @client.snapshots(@client.sprints[1].id)
      snapshots.each do |snap|
        snap.should be_an_instance_of Scrumy::Models::Snapshot
      end
    end
  end
  
end