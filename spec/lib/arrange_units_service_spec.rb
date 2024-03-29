# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArrangeUnitsService, type: :service do
  describe '#call' do
    context '外交フェイズ' do
      context '維持' do
        before :example do
          @table = Table.create(turn_number: 0, phase: Table::Phase::FAL_3RD)
          @power_g = @table.powers.create(symbol: Power::G)
          @turn = @table.turns.create(number: @table.turn_number)
          @unit = @turn.units.create(
            type: Army.to_s,
            power: @power_g,
            phase: @table.phase,
            prov_code: 'bur'
          )
          @table = @table.proceed
          @turn = @table.current_turn
          @order = ListPossibleOrdersService.call(
            turn: @turn,
            power: @power_g,
            unit: @unit
          ).detect(&:hold?)
          @order.succeed
          @turn.orders << @order
        end

        let(:table) { ArrangeUnitsService.call(table: @table) }

        example 'bur にドイツ陸軍があること' do
          unit = @turn.units.where(phase: table.phase).find_by(prov_code: 'bur')
          expect(unit).not_to be_nil
          expect(unit.power).to eq @power_g
          expect(unit.keepout).to be_nil
        end
      end

      context '移動' do
        before :example do
          @table = Table.create(turn_number: 0, phase: Table::Phase::FAL_3RD)
          @power_g = @table.powers.create(symbol: Power::G)
          @turn = @table.turns.create(number: @table.turn_number)
          @unit = @turn.units.create(
            type: Army.to_s,
            power: @power_g,
            phase: @table.phase,
            prov_code: 'bur'
          )
          @table = @table.proceed
          @turn = @table.current_turn
          @order = ListPossibleOrdersService.call(
            turn: @turn,
            power: @power_g,
            unit: @unit
          ).detect { |o| o.dest == 'mar' }
          @order.succeed
          @turn.orders << @order
        end

        let(:table) { ArrangeUnitsService.call(table: @table) }

        example 'bur にドイツ陸軍がないこと' do
          unit = table.current_turn.units.where(
            phase: table.phase
          ).find_by(prov_code: 'bur')
          expect(unit).to be_nil
        end

        example 'mar にドイツ陸軍があること' do
          unit = table.current_turn.units.where(
            phase: table.phase
          ).find_by(prov_code: 'mar')
          expect(unit).not_to be_nil
          expect(unit.power).to eq @power_g
          expect(unit.keepout).to be_nil
        end
      end

      context '支援' do
        before :example do
          @table = Table.create(turn_number: 0, phase: Table::Phase::FAL_3RD)
          @power_g = @table.powers.create(symbol: Power::G)
          @turn = @table.turns.create(number: @table.turn_number)
          @unit_g_bur = @turn.units.create(
            type: Army.to_s,
            power: @power_g,
            phase: @table.phase,
            prov_code: 'bur'
          )
          @unit_g_gas = @turn.units.create(
            type: Army.to_s,
            power: @power_g,
            phase: @table.phase,
            prov_code: 'gas'
          )
          @table = @table.proceed
          @turn = @table.current_turn
          params = { turn: @turn, power: @power_g, unit: @unit_g_bur }
          @order = ListPossibleOrdersService.call(params).detect(&:hold?)
          @order.succeed
          @turn.orders << @order
          params = { turn: @turn, power: @power_g, unit: @unit_g_gas }
          @order = ListPossibleOrdersService.call(params) .detect do |o|
            o.support? && o.target == 'g-a-bur'
          end
          @order.succeed
          @turn.orders << @order
        end

        let(:table) { ArrangeUnitsService.call(table: @table) }

        example 'bur にドイツ陸軍があること' do
          unit = @turn.units.where(phase: table.phase).find_by(prov_code: 'bur')
          expect(unit).not_to be_nil
          expect(unit.power).to eq @power_g
          expect(unit.keepout).to be_nil
        end

        example 'gas にドイツ陸軍があること' do
          unit = @turn.units.where(phase: table.phase).find_by(prov_code: 'gas')
          expect(unit).not_to be_nil
          expect(unit.power).to eq @power_g
          expect(unit.keepout).to be_nil
        end
      end

      context '輸送' do
        before :example do
          @table = Table.create(turn_number: 0, phase: Table::Phase::FAL_3RD)
          @power_e = @table.powers.create(symbol: Power::E)
          @turn = @table.turns.create(number: @table.turn_number)
          @unit_e_lon = @turn.units.create(
            type: Army.to_s,
            power: @power_e,
            phase: @table.phase,
            prov_code: 'lon'
          )
          @unit_e_nth = @turn.units.create(
            type: Fleet.to_s,
            power: @power_e,
            phase: @table.phase,
            prov_code: 'nth'
          )
          @table = @table.proceed
          @turn = @table.current_turn
          params = { turn: @turn, power: @power_e, unit: @unit_e_lon }
          @order = ListPossibleOrdersService.call(params).detect do |o|
            o.dest == 'bel'
          end
          @order.succeed
          @turn.orders << @order
          params = { turn: @turn, power: @power_e, unit: @unit_e_nth }
          @order = ListPossibleOrdersService.call(params).detect do |o|
            o.convoy? && o.target == 'e-a-lon-bel'
          end
          @order.apply
          @turn.orders << @order
        end

        let(:table) { ArrangeUnitsService.call(table: @table) }

        example 'lon にイギリス陸軍がないこと' do
          unit = table.current_turn.units
                      .where(phase: table.phase)
                      .find_by(prov_code: 'lon')
          expect(unit).to be_nil
        end

        example 'bel にイギリス陸軍があること' do
          unit = @turn.units.where(phase: table.phase).find_by(prov_code: 'bel')
          expect(unit).not_to be_nil
          expect(unit.power).to eq @power_e
          expect(unit.keepout).to be_nil
        end

        example 'nth にイギリス海軍があること' do
          unit = @turn.units.where(phase: table.phase).find_by(prov_code: 'nth')
          expect(unit).not_to be_nil
          expect(unit.power).to eq @power_e
          expect(unit.keepout).to be_nil
        end
      end
    end

    context '撤退フェイズ' do
      context '撤退' do
        before :example do
          @table = Table.create(turn_number: 1, phase: Table::Phase::SPR_1ST)
          @power_g = @table.powers.create(symbol: Power::G)
          @turn = @table.turns.create(number: @table.turn_number)
          @unit = @turn.units.create(
            type: Army.to_s,
            power: @power_g,
            phase: @table.phase,
            prov_code: 'bur',
            keepout: 'mar'
          )
          @table = @table.proceed
          @turn = @table.current_turn
          @order = ListPossibleRetreatsService.call(
            power: @power_g, unit: @unit
          ).detect { |r| r.dest == 'par' }
          @order.succeed
          @turn.orders << @order
        end

        let(:table) { ArrangeUnitsService.call(table: @table) }

        example 'par に撤退したドイツ陸軍があること' do
          unit = @turn.units.where(phase: table.phase).find_by(prov_code: 'par')
          expect(unit).not_to be_nil
          expect(unit.power).to eq @power_g
          expect(unit.keepout).to be_nil
        end
      end
    end
  end
end
