ModelusTailoringPolicy = ModelusTailoringPolicy or {}

local Policy = ModelusTailoringPolicy

local function isFiniteNonNegative(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value >= 0
end

local function validDefense(value)
    return type(value) == "table"
        and isFiniteNonNegative(value.scratch)
        and isFiniteNonNegative(value.bite)
end

function Policy.isStrictImprovement(before, after)
    if not validDefense(before) or not validDefense(after) then return false end
    return after.scratch >= before.scratch
        and after.bite >= before.bite
        and (after.scratch > before.scratch or after.bite > before.bite)
end

function Policy.replacementFloor(current, oldPatch, proposed, hasHole)
    if not validDefense(current) or not validDefense(proposed) then return nil end
    if hasHole then
        return { scratch = proposed.scratch, bite = proposed.bite }
    end
    if oldPatch ~= nil and not validDefense(oldPatch) then return nil end
    return {
        scratch = current.scratch + proposed.scratch - (oldPatch and oldPatch.scratch or 0),
        bite = current.bite + proposed.bite - (oldPatch and oldPatch.bite or 0)
    }
end

function Policy.chooseNext(candidates)
    local best
    for index = 1, #candidates do
        local candidate = candidates[index]
        if candidate then
            if not best then
                best = candidate
            else
                local candidatePriority = candidate.priority or math.huge
                local bestPriority = best.priority or math.huge
                local before = candidatePriority < bestPriority
                if candidatePriority == bestPriority then
                    local candidateGarment = candidate.garmentIndex or math.huge
                    local bestGarment = best.garmentIndex or math.huge
                    before = candidateGarment < bestGarment
                    if candidateGarment == bestGarment then
                        local candidatePart = candidate.partIndex or math.huge
                        local bestPart = best.partIndex or math.huge
                        before = candidatePart < bestPart
                        if candidatePart == bestPart then
                            before = candidate.fullRestore == true and best.fullRestore ~= true
                            if candidate.fullRestore ~= true and best.fullRestore ~= true then
                                local candidateBite = candidate.after and candidate.after.bite or -math.huge
                                local bestBite = best.after and best.after.bite or -math.huge
                                before = candidateBite > bestBite
                                if candidateBite == bestBite then
                                    local candidateScratch = candidate.after and candidate.after.scratch or -math.huge
                                    local bestScratch = best.after and best.after.scratch or -math.huge
                                    before = candidateScratch > bestScratch
                                    if candidateScratch == bestScratch then
                                        before = (candidate.fabricOrder or math.huge) < (best.fabricOrder or math.huge)
                                    end
                                end
                            end
                        end
                    end
                end
                if before then best = candidate end
            end
        end
    end
    return best
end

return Policy