require 'code_counter/cli'

describe CodeCounter::CLI do
  it 'should handle a directory name with no group mapping' do
    expect(CodeCounter::CLI.expand_labeled_path('foo/bar')).to eq([File.expand_path('foo/bar'), 'foo/bar'])
  end

  it 'should handle a directory name with a group mapping' do
    expect(CodeCounter::CLI.expand_labeled_path('Meh:foo/bar')).to eq([File.expand_path('foo/bar'), 'Meh'])
  end
end
