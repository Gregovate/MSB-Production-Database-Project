Added 26/06/15 to the Phase 2 / V7 architecture TODO list:

Scene Import Identity Validation (Future Test) 

Purpose
Determine whether LOR preserves identity when a .lorscene file is imported into a different preview.

Test Procedure

Export a known scene from a preview.
Create a throwaway test preview.
Import the .lorscene.
Parse both source and destination previews.
Compare:
SceneID
PropClass.id
PropClass.Name
PropClass.Comment
ChannelGrid
PreviewID

Questions to Answer

Does SceneID remain unchanged?
Does PropClass.id remain unchanged?
Does LOR generate new GUIDs?
Can the same scene exist in multiple previews?
Can imported scenes create duplicate raw PropIDs?

Impact on Architecture

If IDs are preserved:
    .lorscene may be usable as a validation source.

If IDs are regenerated:
    .lorscene must be treated as a portable export only.
    Canonical identity remains the .lorprev parser output.

Priority

Medium
Not required for Phase 2 scene_lor_props implementation.
Required before using .lorscene files for synchronization,
migration, or automated scene imports.

Based on everything we've learned so far, I would continue assuming:

.lorprev = authoritative source
.lorscene = export/interchange format

until that test proves otherwise.