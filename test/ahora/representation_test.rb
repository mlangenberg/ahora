require 'minitest/autorun'
require 'minitest/pride'
require_relative '../test_helper'
require_relative '../../lib/ahora/representation'

class Employee < Ahora::Representation
  boolean :is_rockstar, :slacker, :fired
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