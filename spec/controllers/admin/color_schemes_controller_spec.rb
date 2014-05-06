require 'spec_helper'

describe Admin::ColorSchemesController do
  it "is a subclass of AdminController" do
    (described_class < Admin::AdminController).should be_true
  end

  context "while logged in as an admin" do
    let!(:user) { log_in(:admin) }
    let(:valid_params) { { color_scheme: {
        name: 'Such Design',
        enabled: true,
        colors: [
          {name: '$primary_background_color', hex: 'FFBB00', opacity: '100'},
          {name: '$secondary_background_color', hex: '888888', opacity: '70'}
        ]
      }
    } }

    describe "index" do
      it "returns success" do
        xhr :get, :index
        response.should be_success
      end

      it "returns JSON" do
        Fabricate(:color_scheme)
        xhr :get, :index
        ::JSON.parse(response.body).should be_present
      end
    end

    describe "create" do
      it "returns success" do
        xhr :post, :create, valid_params
        response.should be_success
      end

      it "returns JSON" do
        xhr :post, :create, valid_params
        ::JSON.parse(response.body)['id'].should be_present
      end
    end

    describe "update" do
      let(:existing) { Fabricate(:color_scheme) }

      it "returns success" do
        ColorSchemeRevisor.expects(:revise).returns(existing)
        xhr :put, :update, valid_params.merge(id: existing.id)
        response.should be_success
      end

      it "returns JSON" do
        ColorSchemeRevisor.expects(:revise).returns(existing)
        xhr :put, :update, valid_params.merge(id: existing.id)
        ::JSON.parse(response.body)['id'].should be_present
      end
    end

    describe "destroy" do
      let!(:existing) { Fabricate(:color_scheme) }

      it "returns success" do
        expect {
          xhr :delete, :destroy, id: existing.id
        }.to change { ColorScheme.count }.by(-1)
        response.should be_success
      end
    end
  end
end
