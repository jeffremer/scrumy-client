require 'scrumy'
require 'yaml'

describe Scrumy::Client do
  before(:all) do
    credentials = File.open( 'scrumy_credentials.yml' ) { |yf| YAML::load( yf ) }
    @client = Scrumy::Client.new(credentials['project'], credentials['password'])            
  end
  
  describe '#sprint(id=:current)' do
    it "fetches a full current sprint" do
      sprint = @client.sprint
      sprint.stories.size.should > 0
      sprint.should be_an_instance_of Scrumy::Sprint
    end
  end

  describe '#sprint(id)' do
    it "fetches a sprint by ID" do
      sprints = @client.sprints
      sprint = @client.sprint(sprints[1].id)
      sprint.should be_an_instance_of Scrumy::Sprint
    end
  end
  
  describe '#sprints' do
    it "fetches a list of sprints" do
      @client.sprints.each do |sprint|
        sprint.should be_an_instance_of Scrumy::Sprint
      end
    end
  end
  
  describe '#stories' do
    it "fetches a list of stories based on a sprint" do
      sprints = @client.sprints
      sprints[1].stories.each do |story|
        story.should be_an_instance_of Scrumy::Story
      end
    end
  end
  
  describe '#tasks' do
    it "fetches a list of tasks based on a story" do
      @client.sprints[1].stories[1].tasks do |task|
        task.should be_an_instance_of Scrumy::Task
        task.scrumer.should be_an_instance_of Scrumy::Scrumer
        puts task.scrumer
      end
    end
  end
  
  describe '#scrumers' do
    it "fetches a list of scrumers by scrumy" do
      @client.scrumers.each do |scrumer|
        scrumer.should be_an_instance_of Scrumy::Scrumer
      end
    end
  end
  
  describe '#scrumer' do
    it "fetches a scrumer by name" do
      scrumer = @client.sprint.stories[1].tasks[1].scrumer
      scrumer2 = @client.scrumer(scrumer.name)
      scrumer.name.should == scrumer2.name
      scrumer.color.should == scrumer2.color
    end
  end
  
end