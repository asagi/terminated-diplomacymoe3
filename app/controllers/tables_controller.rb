# frozen_string_literal: true

class TablesController < ApplicationController
  before_action :authenticate, only: [:create]
  before_action :set_table, only: %i[show update destroy]

  def index
    @tables = Table.all
    render json: @tables,
           each_serializer: TableListSerializer,
           include: '**'
  end

  def show
    render json: @table, include: '**'
  end

  def create
    create_table = CreateTableForm.new(owner: @auth_user, params: params)
    unless create_table.save
      raise CustomError::UnprocessableEntity,
            create_table.errors.messages.to_json
    end

    table = create_table.table
    response.headers['Location'] = table_path(table)
    render status: :created, json: { id: table.id }
  end

  private

  def set_table
    id = params[:id]
    num = params[:num]

    if id
      @table = Table.find_by(id: id) || {}
    elsif num
      @table = Table.find_by(number: num) || {}
    end
  end
end
