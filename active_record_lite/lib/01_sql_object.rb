require_relative 'db_connection'
require_relative '02_searchable'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @columns ||= DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
      SQL
      .first.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |column| # column is a symbol
      define_method(column) do # defining a getter method on instance scope
        self.attributes[column]
      end

      define_method("#{column}=") do |value|
        self.attributes[column] = value # defining a setter method on instance scope
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.inspect.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT *
      FROM #{self.table_name}
    SQL

    self.parse_all(results)
  end

  def self.parse_all(results) # results = hash from DB query
    instances = []
    results.each do |result|
      instances << self.new(result)
    end
    instances #it gets turned into an array of objects
  end

  def self.find(id)
    data = DBConnection.execute(<<-SQL, id)
      SELECT *
      FROM #{self.table_name}
      WHERE id = ?
    SQL
    return nil if data.empty?
    self.new(data.first)
  end

  def initialize(params = {}) # take { key: value } pairs
    params.keys.each do |key| # raise error if a key is not a column name
      unless self.class.columns.include? key.to_sym
        raise "unknown attribute '#{key}'"
      end
    end

    params.each do |k,v| # store into instance var @attributes
      self.send("#{k}=", v) #using setter methods made in finalize!
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |column|
      self.send(column)
    end
  end

  def insert # only works if the instance was freshly created
    raise "WTF" if self.id
    col_names = self.class.columns.join(",")
    question_marks = (["?"] * self.attribute_values.length).join(",")
    DBConnection.execute(<<-SQL, *self.attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    # get new id
    self.id = DBConnection.last_insert_row_id
  end

  def update
    raise "WTF" unless self.id
    set_line = self.class.columns.map do |column| # column is a symbol
      "#{column} = ?"
    end.join(",")
    DBConnection.execute(<<-SQL, *self.attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def save
    !!self.id ? update : insert
  end
end
