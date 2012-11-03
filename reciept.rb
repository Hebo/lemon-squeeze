
class Reciept
  attr_accessor :url

  def initialize(reciept)
    @reciept = reciept
    self.url = reciept['image']
  end
  
  def to_s
    "%{date}: %{merchant} - %{total}" % {
      :date => @reciept['date'],
      :merchant => @reciept['merchant'],
      :total => @reciept['total']
    }
  end
end
