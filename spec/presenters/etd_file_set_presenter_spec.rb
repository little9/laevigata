# frozen_string_literal: true
require 'rails_helper'

describe EtdFileSetPresenter do
  context "delegate_methods" do
    subject { presenter }
    let :etd do
      FactoryBot.build(:etd)
    end

    let(:ability) { Ability.new(FactoryBot.build(:user)) }

    let(:presenter) do
      described_class.new(SolrDocument.new(etd.to_solr), ability)
    end

    # If the fields require no addition logic for display, you can simply delegate
    # them to the solr document
    it { is_expected.to delegate_method(:pcdm_use).to(:solr_document) }

    it "returns an array with an empty string from permission_badge" do
      expect(presenter.permission_badge).to eq ""
    end
  end
end
