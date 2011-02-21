require File.dirname(__FILE__) + '/../spec_helper'

describe VenuesController do
  integrate_views
  fixtures :events, :venues

  #Delete this example and add some real ones
  it "should use VenuesController" do
    controller.should be_an_instance_of(VenuesController)
  end

  it "should redirect duplicate venues to their master" do
    venue_master = venues(:cubespace)
    venue_duplicate = venues(:duplicate_venue)

    get 'show', :id => venue_duplicate.id
    response.should_not be_redirect
    assigns(:venue).id.should == venue_duplicate.id

    venue_duplicate.duplicate_of = venue_master
    venue_duplicate.save!

    get 'show', :id => venue_duplicate.id
    response.should be_redirect
    response.should redirect_to(venue_url(venue_master.id))
  end

  it "should display an error message if given invalid arguments" do
    get 'duplicates', :type => 'omgwtfbbq'

    response.should be_success
    response.should have_tag('.failure', :text => /omgwtfbbq/)
  end
  
  describe "when creating venues" do
    it "should stop evil robots" do
      post :create, :trap_field => "I AM AN EVIL ROBOT, I EAT OLD PEOPLE'S MEDICINE FOR FOOD!"
      response.should render_template(:new)
    end
  end
  
  describe "when updating venues" do 
    before(:each) do
      @venue = stub_model(Venue)
      Venue.stub!(:find).and_return(@venue)
    end
    
    it "should stop evil robots" do
      put :update,:id => '1', :trap_field => "I AM AN EVIL ROBOT, I EAT OLD PEOPLE'S MEDICINE FOR FOOD!"
      response.should render_template(:edit)
    end
  end

  describe "when rendering the venues index" do
    before(:all) do
      @open_venue = Venue.create!(:title => 'Open Town', :description => 'baz')
      @closed_venue = Venue.create!(:title => 'Closed Down', :closed => true)
      @wifi_venue = Venue.create!(:title => "Internetful", :wifi => true)
    end

    describe "with no parameters" do
      before do
        get :index
      end

      it "should assign @most_active_venues and @newest_venues by default" do
        get :index
        assigns[:most_active_venues].should_not be_nil
        assigns[:newest_venues].should_not be_nil
      end

      it "should not included closed venues" do
        assigns[:newest_venues].should_not include @closed_venue
      end
    end

    describe "and showing all venues" do
      it "should include closed venues when asked to with the include_closed parameter" do
        get :index, :all => '1', :include_closed => '1'
        assigns[:venues].should include @closed_venue
      end

      it "should include ONLY closed venues when asked to with the closed parameter" do
        get :index, :all => '1', :closed => '1'
        assigns[:venues].should include @closed_venue
        assigns[:venues].should_not include @open_venue
      end
    end

    describe "when searching" do
      describe "for public wifi (and no keyword)" do
        before do
          get :index, :query => '', :wifi => '1'
        end

        it "should only include results with public wifi" do
          assigns[:venues].should include @wifi_venue
          assigns[:venues].should_not include @open_venue
        end
      end

      describe "when searching by keyword" do
        it "should find venues by title" do
          get :index, :query => 'Open Town'
          assigns[:venues].should include @open_venue
          assigns[:venues].should_not include @wifi_venue
        end
        it "should find venues by description" do
          get :index, :query => 'baz'
          assigns[:venues].should include @open_venue
          assigns[:venues].should_not include @wifi_venue
        end

        describe "and requiring public wifi" do
          it "should not find venues without public wifi" do
            get :index, :query => 'baz', :wifi => '1'
            assigns[:venues].should_not include @open_venue
            assigns[:venues].should_not include @wifi_venue
          end
        end
      end


    end

    it "should be able to return events matching specific tag" do
      Venue.should_receive(:tagged_with).with("foo").and_return([])
      get :index, :tag => "foo"
    end

    describe "in JSON format" do
      it "should produce JSON" do
        get :index, :format => "json"

        struct = ActiveSupport::JSON.decode(response.body)
        struct.should be_a_kind_of(Array)
      end

      it "should accept a JSONP callback" do
        get :index, :format => "json", :callback => "some_function"

        response.body.split("\n").join.should match(/^\s*some_function\(.*\);?\s*$/)
      end
    end

  end

  describe "when showing venues" do

    before(:each) do
      @venue = Venue.find(:first)
    end

    describe "in JSON format" do

      it "should produce JSON" do
        get :show, :id => @venue.to_param, :format => "json"

        struct = ActiveSupport::JSON.decode(response.body)
        struct.should be_a_kind_of(Hash)
      end

      it "should accept a JSONP callback" do
        get :show, :id => @venue.to_param, :format => "json", :callback => "some_function"

        response.body.split("\n").join.should match(/^\s*some_function\(.*\);?\s*$/)
      end

    end

  end
      
  
end
