def init
  puts 'INIT'
  [$showCompleted, $showNotCompleted].each do |checkBox|
    checkBox.add_otchange_listener do |event|
      puts 'EV'
      $viewContainer.parentContainer.reloadView
    end
  end
  true
end

def save
end
