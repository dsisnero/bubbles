require "../spec_helper"
require "../../src/bubbles/internal/memoization"

describe Bubbles::Internal::Memoization do
  it "TestCache" do
    tests = {
      "TestNewMemoCache" => {
        capacity: 5,
        actions:  [
          {action: "get", key: "", value: nil, expected: nil},
        ],
      },
      "TestSetAndGet" => {
        capacity: 10,
        actions:  [
          {action: "set", key: "key1", value: "value1", expected: nil},
          {action: "get", key: "key1", value: nil, expected: "value1"},
          {action: "set", key: "key1", value: "newValue1", expected: nil},
          {action: "get", key: "key1", value: nil, expected: "newValue1"},
          {action: "get", key: "nonExistentKey", value: nil, expected: nil},
          {action: "set", key: "nilKey", value: "", expected: nil},
          {action: "get", key: "nilKey", value: nil, expected: ""},
          {action: "set", key: "keyA", value: "valueA", expected: nil},
          {action: "set", key: "keyB", value: "valueB", expected: nil},
          {action: "get", key: "keyA", value: nil, expected: "valueA"},
          {action: "get", key: "keyB", value: nil, expected: "valueB"},
        ],
      },
      "TestGetAfterEviction" => {
        capacity: 2,
        actions:  [
          {action: "set", key: "1", value: "1", expected: nil},
          {action: "set", key: "2", value: "2", expected: nil},
          {action: "set", key: "3", value: "3", expected: nil},
          {action: "get", key: "1", value: nil, expected: nil},
          {action: "get", key: "2", value: nil, expected: "2"},
        ],
      },
      "TestGetAfterLRU" => {
        capacity: 2,
        actions:  [
          {action: "set", key: "1", value: "1", expected: nil},
          {action: "set", key: "2", value: "2", expected: nil},
          {action: "get", key: "1", value: nil, expected: "1"},
          {action: "set", key: "3", value: "3", expected: nil},
          {action: "get", key: "1", value: nil, expected: "1"},
          {action: "get", key: "3", value: nil, expected: "3"},
          {action: "get", key: "2", value: nil, expected: nil},
        ],
      },
    }

    tests.each do |name, tc|
      cache = Bubbles::Internal::Memoization::MemoCache(Bubbles::Internal::Memoization::HString, String).new(tc[:capacity])
      tc[:actions].each do |action|
        key = Bubbles::Internal::Memoization::HString.new(action[:key])
        if action[:action] == "set"
          cache.set(key, action[:value].to_s)
          next
        end

        got, found = cache.get(key)
        if expected = action[:expected]
          found.should be_true, "#{name}: expected key to be present"
          got.should eq(expected), "#{name}: expected #{expected.inspect}, got #{got.inspect}"
        else
          found.should be_false, "#{name}: expected key to be absent"
          got.should be_nil
        end
      end
    end
  end
end
