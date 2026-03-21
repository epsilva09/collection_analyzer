# Armory Comparison Payload Mapping

Date: 2026-03-20
Owner: epsilva09 + GitHub Copilot

This document consolidates the endpoint payload mapping used to design new
comparison experiences.

## Endpoint Summary

### 1) Character Overview

- Endpoint: `/api/website/armory?name={character_name}`
- Purpose: identity and macro combat profile.
- Key fields:
  - `character.characterIdx`, `character.name`, `character.level`
  - `character.atackPower`, `character.defensePoint`
  - `character.atackPowerPVE`, `character.defensePowerPVE`
  - `character.atackPowerPVP`, `character.defensePowerPVP`
  - `character.mythScore`, `character.forceWingGrade`, `character.honorMedalGrade`

### 2) Collection

- Endpoint: `/api/website/armory/collection/{character_idx}`
- Purpose: progression and collection bonus state.
- Key fields:
  - `values[]` (summary bonuses)
  - `data[].collections[].progress`
  - `data[].collections[].rewards[]` (`applied`, `description`, `value`)
  - `data[].collections[].missions[].data[]`
    - `name`, `max`, `progress`, `done`, `items[]`

### 3) Myth

- Endpoint: `/api/website/armory/myth/{character_idx}`
- Purpose: myth progression, grade gates, and line-by-line power composition.
- Key fields:
  - `level`, `maxLevel`, `grade`, `gradeName`
  - `point`, `maxPoint`, `score`, `totalScore`
  - `stigma` (`score`, `maxScore`, `grade`)
  - `grades[]` (`enabled`, `point`, `force`)
  - `lines[][]` (`level`, `maxLevel`, `name`, `score`, `locked`)
  - `values[]` (myth bonus aggregation)

### 4) Force Wing

- Endpoint: `/api/website/armory/force-wing/{character_idx}`
- Purpose: wing grade, level, and active buffs.
- Key fields:
  - `grade`, `gradeName`, `level`
  - `gradeData[]` (`name`, `gradeName`, `forces[]`)
  - `status[]` (base status bonuses)
  - `buffValue[]` (active wing buff bonuses)

### 5) Honor Medal

- Endpoint: `/api/website/armory/honor-medal/2/{character_idx}`
- Purpose: grade progression with slot-based force composition.
- Key fields:
  - `currentGrade`, `currentGradeName`, `level`, `percent`
  - `grades[]`
    - `grade`, `name`
    - `slots[]` (`opened`, `level`, `maxLevel`, `description`, `forceId`, `forceValue`)
  - `values[]` (medal bonus aggregation)

### 6) Stellar

- Endpoint: `/api/website/armory/stellar/{character_idx}`
- Purpose: line progression and set bonus combinations.
- Key fields:
  - `values[]` (stellar aggregate bonuses)
  - `lines[]`
    - `line`, `level`
    - `setValues[]`
    - `data[]` (`name`, `force`, `value`, `level`)

### 7) Ability

- Endpoint: `/api/website/armory/ability/{character_idx}`
- Purpose: full ability build profile.
- Key fields:
  - `passive[]` (`name`, `level`, `force`)
  - `blended[]` (`name`, `target`, `force`)
  - `karma[]` (`name`, `level`, `force`)

## Comparison Views Enabled by This Mapping

## 1) Character Overview A vs B

- Inputs: character overview + summary from myth, wing, medal, stellar.
- Output: AP/DP PVE/PVP deltas, progression summary, top differentiators.

## 2) Progression Gap Dashboard

- Inputs: myth, wing, medal, stellar.
- Output: current vs max levels, grade gap, missing points, next milestone.

## 3) Collection Macro Comparison

- Inputs: collection progress/rewards.
- Output: completed vs in-progress collections, near-complete list, unlocked reward tiers.

## 4) Collection Missing Materials Comparison

- Inputs: collection missions data.
- Output: missing item deltas, shared farm opportunities, recommended next target.

## 5) Myth Deep Comparison

- Inputs: myth lines, values, grades.
- Output: line strength gap, locked nodes, score-to-next-grade.

## 6) Force Wing Comparison

- Inputs: wing gradeData/status/buffValue.
- Output: grade and level gap, active buff differences.

## 7) Honor Medal Slot Comparison

- Inputs: medal grades/slots/values.
- Output: slot heatmap by grade, opened slot ratio, force concentration by attribute.

## 8) Stellar Line Comparison

- Inputs: stellar lines/setValues/values.
- Output: line maturity, set-value differences, aggregate stat deltas.

## 9) Ability Build Comparison

- Inputs: ability passive/blended/karma.
- Output: PVE/PVP profile comparison and build specialization map.

## 10) Composite PVE vs PVP Profile

- Inputs: aggregated fields from all systems.
- Output: weighted profile score for PVE and PVP, with explanation by source system.

## Cross-Endpoint Data Normalization Notes

- API names include mixed conventions (example: `atackPower` typo from source).
- Force labels can repeat across systems with different magnitudes.
- Collection rewards should continue to use progress-based resolution as source of truth
  (see `CollectionRewardResolver`) to avoid under-reporting from payload flags.
- Comparison services should normalize to a shared stat key map before summing values.

## Proposed Delivery Cycles and Sprints

## Cycle 33 - Sprint 1 (Foundation)

- Add endpoint wrappers in `ArmoryClient` for myth, force wing, honor medal,
  stellar, and ability with caching and timeout handling.
- Add parser/normalizer service objects per endpoint.
- Add contract tests for payload shape and malformed fields.

## Cycle 34 - Sprint 2 (Core Comparison Screens)

- Build Character Overview A vs B.
- Build Progression Gap Dashboard (myth, wing, medal, stellar).
- Build Collection Macro Comparison with consistent reward resolution.

## Cycle 35 - Sprint 3 (Deep-Dive Screens)

- Build Myth Deep Comparison.
- Build Honor Medal Slot Comparison.
- Build Stellar Line Comparison.
- Build Ability Build Comparison.

## Cycle 36 - Sprint 4 (Prioritization and UX)

- Add missing-material prioritization and shared farm recommendation.
- Add PVE/PVP composite profile scoring and explanation cards.
- Add responsive tuning, loading/error states, and accessibility pass.
- Add comparison snapshots for temporal trend analysis.
