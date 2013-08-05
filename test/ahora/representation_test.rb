require 'minitest/autorun'
require 'minitest/pride'
require_relative '../test_helper'
require_relative '../../lib/ahora/representation'

class Employee < Ahora::Representation
  string :first_name, :last_name
  boolean :is_rockstar, :slacker, :fired
  float :rating
end

describe "boolean elements" do
  let(:employee) { Employee.parse(fixture('employee').read) }

  it "parsing 'true' adds the correct reader" do
    employee.is_rockstar.must_equal true
    employee.is_rockstar = false
    employee.is_rockstar.must_equal false
    employee.is_rockstar?.must_equal false
  end

  it "parsing 'false' adds the correct reader" do
    employee.slacker.must_equal false
  end

  it "parsing missing value adds the correct reader" do
    employee.fired.must_equal nil
  end

  it "parsing 'true' adds the correct question mark reader" do
    employee.is_rockstar?.must_equal true
  end

  it "parsing 'false' adds the correct question mark reader" do
    employee.slacker?.must_equal false
  end

  it "parsing missing value adds the correct question mark reader" do
    employee.fired?.must_equal false
  end
end

describe "float elements" do
  let(:employee) { Employee.parse(fixture('employee').read) }

  it "parses float elements" do
    employee.rating.must_equal 7.8
  end
end

describe "string elements" do
  let(:employee) { Employee.parse(fixture('employee').read) }

  it "returns regular strings" do
    employee.first_name.must_equal 'John'
  end

  it "returns nil for empty strings" do
    employee.last_name.must_equal nil
  end
end