class ResoluteOrdersService
  def self.call(orders:)
    self.new(orders: orders).call
  end


  def initialize(orders:)
    @orders = orders.to_a
    @standoff = []
  end


  def call
    # ステータス初期化
    initialize_status

    # 無効支援除外
    remove_unmatched_support_orders

    # 支援カット判定
    resolute_cutting_support_orders

    # 支援適用
    apply_support_orders

    # 輸送適用
    apply_convoy_orders

    # 交換移動命令解決
    resolute_switch_orders

    # 輸送妨害の優先解決
    resolute_disturb_convoy_orders

    # 支援妨害の優先解決
    resolute_disturb_support_orders

    # その他移動命令解決
    resolute_other_move_orders

    # 未処理維持命令成功判定
    resolute_hold_orders

    return @orders, @standoff
  end


  private
  # ステータス初期化
  def initialize_status
    @orders.each do |o|
      o.status = Order::UNSLOVED
      o.support = 0
      o.keepout = nil
    end
  end


  # 無効支援除外
  def remove_unmatched_support_orders
    supports = unsloved_support_orders
    supports.each do |s|
      s.status = Order::UNMATCHED unless @orders.detect{|o| o.to_key == s.target}
    end
  end


  # 支援カット判定
  def resolute_cutting_support_orders
    unsloved_support_orders.each do |s|
      moves = unsloved_move_orders.select{|m| s.unit.province == m.dest}
      enemies = moves.select{|m| m.power != s.power}
      if enemies.size > 1
        s.status = Order::CUT
        next
      end

      next if enemies.empty?
      enemy = enemies[0]

      support_target = @orders.detect{|o| o.to_key == s.target}
      unless support_target.move?
        s.status = Order::CUT
        next
      end

      if support_target.dest == enemy.unit.province
        # カットされない
        next
      end

      # 遠隔攻撃？
      if Map.adjacents[s.unit.province].detect{|code, data| code == enemy.unit.province}
        # 違った
        s.status = Order::CUT
        next
      end

      attack_target = @orders.detect{|o| o.unit.province == support_target.dest}
      unless attack_target
        s.status = Order::CUT
        next
      end

      unless attack_target.convoy?
        s.status = Order::CUT
        next
      end

      unless enemy.to_key == attack_target.target
        s.status = Order::CUT
        next
      end

      # 輸送経路判定処理
      convoys = @orders.select{|o| o.convoy? && o.target == enemy.to_key}
      convoys = convoys.select{|c| c != attack_target}
      fleets = convoys.map{|c| c.unit}
      coastals = SearchReachableCoastalsService.call(unit: enemy.unit, fleets: fleets)
      s.status = Order::CUT if coastals.include?(enemy.dest)
    end
  end


  # 支援適用
  def apply_support_orders
    supports = unsloved_support_orders
    supports.each do |s|
      target = @orders.detect{|o| o.to_key == s.target}
      if target
        target.support += 1
        s.apply
      else
        s.reject
      end
    end
  end


  # 輸送適用
  def apply_convoy_orders
    # 輸送経路成立チェック
    unsloved_move_orders.each do |m|
      convoys = unsloved_convoy_orders
      next if convoys.empty?
      fleets = convoys.map{|c| c.unit}
      coastals = SearchReachableCoastalsService.call(unit: m.unit, fleets: fleets)
      if coastals.include?(m.dest)
        # 経路成立
        convoys.each{|c| c.apply}
      else
        # 経路不成立
        convoys.each{|c| c.reject}
      end
    end

    # 輸送経路不成立の輸送対象移動命令のリジェクト
    unsloved_move_orders.each do |m|
      next unless m.unit.army?
      next unless Map.provinces[m.unit.province]['type'] == Coastal.to_s
      if Map.adjacents[m.unit.province][m.dest]
        next if Map.adjacents[m.unit.province][m.dest][m.unit.type.downcase]
      end
      next if sea_route_effective?(move: m)
      m.reject
    end
  end


  # 交換移動命令解決
  def resolute_switch_orders
    dests = unsloved_move_orders.map{|m| m.dest}.uniq
    return if dests.empty?

    dests.each do |dest|
      next unless move = unsloved_move_orders.detect{|m| m.dest == dest}
      next unless against = unsloved_move_orders.detect{|m| m.unit.province == dest && m.dest == move.unit.province }

      next if sea_route_effective?(move: move)
      next if sea_route_effective?(move: against)

      if move.support > against.support
        move.succeed
        against.dislodge(against: move)
      elsif move.support < against.support
        move.dislodge(against: against)
        against.succeed
      else
        move.fail
        against.fail
      end
    end
  end


  # 輸送妨害の優先解決
  def resolute_disturb_convoy_orders
    convoys = @orders.select{|o| o.convoy?}
    dests = convoys.map{|c| c.unit.province}
    dests.each do |dest|
      resolute_move_orders_core(dest: dest)
    end

    unsloved_move_orders.each do |m|
      convoys = @orders.select{|o| o.convoy? && o.applied? && o.target == m.to_key}
      next if convoys.empty?
      fleets = convoys.map{|c| c.unit}
      coastals = SearchReachableCoastalsService.call(unit: m.unit, fleets: fleets)
      m.fail unless coastals.include?(m.dest)
    end
  end


  # 支援妨害の優先解決
  def resolute_disturb_support_orders
    dests = @orders.select{|o| o.support?}.map{|s| s.unit.province}
    return if dests.empty?

    dests.each do |dest|
      # 移動命令解決
      resolute_move_orders_core(dest: dest)
    end
  end


  # その他移動命令解決
  def resolute_other_move_orders
    loop do
      dests = unsloved_move_orders.map{|m| m.dest}.uniq
      break if dests.empty?

      dests.each do |dest|
        # 移動命令解決
        resolute_move_orders_core(dest: dest)
      end
    end
  end


  # 未処理維持命令成功判定
  def resolute_hold_orders
    holds = @orders.select{|o| o.hold? && o.unsloved?}
    holds.each{|h| h.succeed}
  end


  def resolute_move_orders_core(dest:)
    moves = unsloved_move_orders.select{|m| m.dest == dest && m.unsloved?}
    return if moves.size == 0

    # 複数の衝突
    if moves.size > 1
      support_level_list = moves.map{|m| m.support}
      max_support_level = support_level_list.max
      winner = nil
      if support_level_list.count(max_support_level) == 1
        winner = moves.detect{|m| m.support == max_support_level}
      end
      moves.map do |m|
        next if winner && m == winner
        m.fail
        against = rewind_move_order_to(province: m.unit.province)
        m.dislodge(against: against) if against
      end
      @standoff << dest unless winner
      return
    end

    # 入ってます
    move = moves[0]
    hold = hold_orders.detect{|h| h.unit.province == dest}

    # 暫定成功
    unless hold
      move.succeed
      return
    end

    # 移動先と同じ軍からの支援をリジェクト
    @orders.select{|o| o.support? && o.target == move.to_key}.each do |s|
      next unless s.power == hold.power
      s.reject
      move.support -= 1
    end

    # 移動失敗
    if hold.support >= move.support || hold.power == move.power
      move.fail
      @orders.select{|o| o.support? && o.target == move.to_key}.each do |s|
        next unless move.power == hold.power
        s.reject
      end

      against = rewind_move_order_to(province: move.unit.province)
      move.dislodge(against: against) if against
      return
    end

    # 移動成功
    move.succeed
    hold.dislodge(against: move)

    # 撃退されたのが支援命令だった場合
    return unless hold.target
    target = @orders.detect{|o| o.to_key == hold.target}
    return unless target
    return unless hold.support?
    target.status = Order::UNSLOVED
    target.support -= 1
    return unless  target.dest
    @orders.select{|o| o.move? && o.dest == target.dest}.each do |m|
      return if m == target
      m.status = Order::UNSLOVED
    end
  end


  # 海路有効判定
  def sea_route_effective?(move:)
    convoys = applied_convoy_orders.select{|c| c.target == move.to_key}
    fleets = convoys.map{|c| c.unit}
    coastals = SearchReachableCoastalsService.call(unit: move.unit, fleets: fleets)
    coastals.include?(move.dest)
  end


  def rewind_move_order_to(province:)
    against_move = @orders.detect{|o| o.dest == province && o.succeeded?}
    return nil unless against_move
    if against_move && against_move.support > 0
      against_move.succeed
      return against_move
    end
    against_move.status = Order::UNSLOVED
    return nil
  end


  def hold_orders
    holds = @orders.select{|o| !o.move?}
    holds += @orders.select{|o| o.move? && (o.failed? || o.dislodged?)}
    holds
  end


  def unsloved_move_orders
    @orders.select{|o| o.move? && o.unsloved?}
  end


  def unsloved_support_orders
    @orders.select{|o| o.support? && o.unsloved?}
  end


  def unsloved_convoy_orders
    @orders.select{|o| o.convoy? && o.unsloved?}
  end


  def applied_convoy_orders
    @orders.select{|o| o.convoy? && o.applied?}
  end
end