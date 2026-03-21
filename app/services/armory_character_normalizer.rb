class ArmoryCharacterNormalizer
  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    {
      character_idx: to_i(@payload["characterIdx"]),
      name: @payload["name"].to_s,
      level: to_i(@payload["level"]),
      battle_style: to_i(@payload["battleStyle"]),
      guild: @payload["guild"].to_s,
      attack_power: to_i(@payload["atackPower"]),
      defense_power: to_i(@payload["defensePoint"]),
      attack_power_pve: to_i(@payload["atackPowerPVE"]),
      defense_power_pve: to_i(@payload["defensePowerPVE"]),
      attack_power_pvp: to_i(@payload["atackPowerPVP"]),
      defense_power_pvp: to_i(@payload["defensePowerPVP"]),
      myth_score: to_i(@payload["mythScore"]),
      myth_grade: to_i(@payload["mythGrade"]),
      myth_grade_name: @payload["mythGradeName"].to_s,
      force_wing_grade: to_i(@payload["forceWingGrade"]),
      force_wing_grade_name: @payload["forceWingGradeName"].to_s,
      force_wing_level: to_i(@payload["forceWingLevel"]),
      honor_medal_grade: to_i(@payload["honorMedalGrade"]),
      honor_medal_grade_name: @payload["honorMedalGradeName"].to_s,
      honor_medal_level: to_i(@payload["honorMedalLevel"]),
      achievement_point: to_i(@payload["achievementPoint"])
    }
  end

  private

  def to_i(value)
    value.to_i
  end
end
