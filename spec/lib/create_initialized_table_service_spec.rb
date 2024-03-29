# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateInitializedTableService, type: :service do
  before :example do
    @master = create(:master)
  end

  let(:master) do
    table.all_players.find_by(status: Player::Status::MASTER)
  end
  let(:user) { create(:user) }
  let(:table) { CreateInitializedTableService.call(owner: { user: user }) }
  let(:turn_0) { table.turns.last }
  let(:units) { turn_0.units.where(phase: table.phase).where(power: @power) }
  let(:provinces) { turn_0.provinces }
  let(:r_supplycenters) do
    provinces.where(power: Power::R).where(supplycenter: true)
  end

  describe '#call' do
    describe '国' do
      example '7 国 が生成されている' do
        expect(table.powers.size).to eq 7
      end
    end

    describe 'プレイヤー' do
      example '生成された卓には最初のプレイヤーとして卓を立てたユーザーが登録されている' do
        expect(table.players.size).to eq 1
        expect(table.players.find_by(user_id: user.id)).not_to be_nil
      end
    end

    describe 'ターン' do
      example '開幕ターンのみが生成されている' do
        expect(table.turns.size).to eq 1
        expect(turn_0.number).to eq 0
      end

      describe '地域' do
        example '開幕ターンに領土情報が生成されている' do
          expect(provinces).not_to be_nil
        end

        example 'ロシアは 4 つの補給都市を持つ' do
          expect(r_supplycenters.size).to eq 4
        end
      end

      describe 'ユニット' do
        example 'イタリアは 2 つの陸軍と 1 つの海軍を持つ' do
          @power = table.powers.find_by(symbol: Power::I)
          expect(units.where(type: Army.to_s).size).to eq 2
          expect(units.where(type: Fleet.to_s).size).to eq 1
        end
      end
    end
  end
end
