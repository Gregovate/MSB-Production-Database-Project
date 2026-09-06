/*
 * 2025 Setup verification prototype extensions.
 *
 * Adds a broader provisional task catalog and an instruction-review surface
 * without changing PostgreSQL or the production Procedure application.
 */

const supplementalTasks = [
  {
    id: 'MC-FRAME', stageKey: '03a', stageName: 'Mega Cube', order: 10,
    name: 'Install Mega Cube Frame and Panels', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Mega Cube frame and panels are installed and ready for controller/final hookup work.',
    notes: 'Representative reusable task reconstructed from Setup planning discussion; verify exact task boundary.',
    dependencies: [], material: 'Required Mega Cube Displays/Containers to be resolved from current Production Database.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'MC-CONTROLLER', stageKey: '03a', stageName: 'Mega Cube', order: 20,
    name: 'Controller / Final Hookup', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Mega Cube controller/final hookup work is complete.',
    notes: 'Verify whether this is independently schedulable or belongs in the frame/panel task.',
    dependencies: ['MC-FRAME'], material: 'Controller and wiring relationships to be resolved from current Production Database.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'OPS-FOOD', stageKey: '04', stageName: 'General / Operations', order: 10,
    name: 'Arrange Volunteer Food', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'None / to verify',
    completion: 'Volunteer food arrangements for the applicable Setup period are confirmed.',
    notes: 'Inventory-independent support task with Stage 04 general-area context.',
    dependencies: [], material: 'No Display/KIT material required.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'OPS-RENTALS', stageKey: '04', stageName: 'General / Operations', order: 20,
    name: 'Arrange Rental Equipment', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Rental equipment planning',
    completion: 'Required rental equipment and availability are confirmed.',
    notes: 'Inventory-independent support task with Stage 04 general-area context.',
    dependencies: [], material: 'No Display/KIT material required.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'OPS-VOLTRAILER', stageKey: '04', stageName: 'General / Operations', order: 30,
    name: 'Position Volunteer Trailer', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Truck / trailer capability',
    completion: 'Volunteer Trailer is positioned in the intended Stage 04 general area.',
    notes: 'Inventory-independent support task with field context.',
    dependencies: [], material: 'No Display/KIT material required unless a reviewed support Container relationship is later justified.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'FC-ARCHES', stageKey: '04', stageName: 'Food Collection', order: 20,
    name: 'Install Food Collection Arches', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Food Collection arches are installed in their intended field positions.',
    notes: 'Late-season timing may apply; verify exact date window and relationship to traffic-lane work.',
    dependencies: ['FC-UNLOAD'], material: 'Food Collection arch Displays from Container 34 plus any reviewed support material.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'FC-TRAFFIC', stageKey: '04', stageName: 'Food Collection', order: 30,
    name: 'Set Food Collection Traffic Lanes', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Food Collection traffic lanes are configured for the intended event flow.',
    notes: 'Intentionally delayed until near VIP night; verify exact reusable date/window guidance.',
    dependencies: [], material: 'To verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'WH-SCAFFOLD', stageKey: '07', stageName: 'Whoville', order: 10,
    name: 'Set Whoville Scaffold', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Scaffold / to verify',
    completion: 'Required Whoville scaffold is positioned and ready for dependent work.',
    notes: 'Verify exact relationship to Mt Crumpit and other Whoville work.',
    dependencies: [], material: 'To verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'WH-CRUMPIT', stageKey: '07', stageName: 'Whoville', order: 20,
    name: 'Install Mt Crumpit Panels', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Mt Crumpit panels are installed.',
    notes: 'Provisional task boundary.',
    dependencies: ['WH-SCAFFOLD'], material: 'Required Displays/Containers to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'WH-SPIRAL', stageKey: '07', stageName: 'Whoville', order: 30,
    name: 'Install Who Spiral Tree and Star', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Who Spiral Tree and Star are installed.',
    notes: 'Provisional task boundary.',
    dependencies: [], material: 'Required Displays/Containers to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'WH-CHARACTERS', stageKey: '07', stageName: 'Whoville', order: 40,
    name: 'Place Whoville Characters', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Whoville character Displays are placed in their intended field locations.',
    notes: 'Provisional reusable task.',
    dependencies: [], material: 'Required Displays/Containers to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'WH-WHOHOUSE', stageKey: '07', stageName: 'Whoville', order: 50,
    name: 'Build / Finish Who House on Arch Trailer', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Arch Trailer / to verify',
    completion: 'Arch Trailer is empty and in Whoville, and the Who House is built/finished on the trailer base.',
    notes: 'Container 34 becomes the Who House base only after its cargo is unloaded. Who House itself is stored elsewhere and must not be assigned to Container 34.',
    dependencies: ['RA-UNLOAD', 'PB-UNLOAD', 'IT-UNLOAD', 'ST-UNLOAD', 'CL-UNLOAD', 'FC-UNLOAD'],
    material: 'Container 34 as support/base after unload; Who House material comes from its own current Production Database relationships.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'EC-SCAFFOLD', stageKey: '08', stageName: 'Elf Choir', order: 10,
    name: 'Set Scaffold and Elves', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Scaffold / to verify',
    completion: 'Elf Choir scaffold and elf Displays are installed.',
    notes: 'Verify final wording and whether scaffold and elves remain one practical task.',
    dependencies: [], material: 'Required Displays/Containers to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'EC-NOTES', stageKey: '08', stageName: 'Elf Choir', order: 20,
    name: 'Install Notes and Conductor', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Notes and conductor Displays are installed.',
    notes: 'Provisional reusable task.',
    dependencies: ['EC-SCAFFOLD'], material: 'Required Displays/Containers to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'ST-HARNESS', stageKey: '10', stageName: 'Stars', order: 20,
    name: 'Install Star Harness', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Star harness is installed and ready for the 24 stars.',
    notes: 'Provisional task boundary.',
    dependencies: ['ST-UNLOAD'], material: 'Harness/support material plus current Star Display relationships.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'ST-HANG', stageKey: '10', stageName: 'Stars', order: 30,
    name: 'Put Up 24 Stars', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'All 24 Star Stage stars are installed.',
    notes: 'All 24 stars are carried on Container 34 during transport.',
    dependencies: ['ST-HARNESS'], material: '24 Star Displays currently transported on Container 34.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'IT-INSTALL', stageKey: '14', stageName: 'Icicle Tunnel', order: 20,
    name: 'Install Icicle Tunnel', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Icicle Tunnel Display group is installed.',
    notes: 'Provisional reusable task after bulk unload.',
    dependencies: ['IT-UNLOAD'], material: '36 Icicle Tunnel Displays currently transported on Container 34.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'CL-ARCH', stageKey: '17', stageName: 'Candyland', order: 20,
    name: 'Install Candyland Arch and Pinwheels', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Candyland arch and pinwheels are installed.',
    notes: 'Provisional reusable task.',
    dependencies: ['CL-UNLOAD'], material: 'Candyland Arch Displays from Container 34 plus pinwheels/current support relationships.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'CL-LOLLIPOP', stageKey: '17', stageName: 'Candyland', order: 30,
    name: 'Position Lollipop Trailer', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Truck / trailer capability',
    completion: 'Lollipop Trailer is positioned in Candyland.',
    notes: 'Verify exact task/material relationship.',
    dependencies: [], material: 'Current Production Database relationship to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'CL-BENCHES', stageKey: '17', stageName: 'Candyland', order: 40,
    name: 'Set Tree Benches', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Candyland tree benches are placed.',
    notes: 'Provisional reusable task.',
    dependencies: [], material: 'Current Production Database relationship to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'CL-GINGERBREAD', stageKey: '17', stageName: 'Candyland', order: 50,
    name: 'Install Gingerbread House and Panels', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Gingerbread House and panels are installed.',
    notes: 'Provisional reusable task.',
    dependencies: [], material: 'Current Production Database relationship to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'CL-CANES', stageKey: '17', stageName: 'Candyland', order: 60,
    name: 'Install Candy Canes', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Candy cane Displays are installed.',
    notes: 'Provisional reusable task.',
    dependencies: [], material: 'Current Production Database relationship to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'PB-THROW', stageKey: '21', stageName: 'Polar Bear Playground', order: 20,
    name: 'Install Throwing Bears and Arch', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Throwing Bears and Polar Bear arch are installed.',
    notes: 'Provisional reusable task.',
    dependencies: ['PB-UNLOAD'], material: 'Polar Bear arch group from Container 34 plus required current Displays/Containers.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'PB-IGLOOS', stageKey: '21', stageName: 'Polar Bear Playground', order: 30,
    name: 'Install Polar Bear Igloos', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Polar Bear igloos are installed.',
    notes: 'Provisional reusable task.',
    dependencies: [], material: 'Current Production Database relationship to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'PB-PANELS', stageKey: '21', stageName: 'Polar Bear Playground', order: 40,
    name: 'Install Polar Bear Panels', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Polar Bear Playground panels are installed.',
    notes: 'Provisional reusable task.',
    dependencies: [], material: 'Current Production Database relationship to verify.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'RA-HARNESS', stageKey: '25', stageName: 'Racing Arches', order: 20,
    name: 'Install Racing Arch Harness', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Racing Arch harness/support is installed and ready for arches.',
    notes: 'Provisional reusable task.',
    dependencies: ['RA-UNLOAD'], material: 'Harness/support plus Racing Arch Display group.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'RA-ARCHES', stageKey: '25', stageName: 'Racing Arches', order: 30,
    name: 'Install Racing Arches', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Racing Arches are installed.',
    notes: 'Provisional reusable task after harness/support work.',
    dependencies: ['RA-HARNESS'], material: '48 Racing Arches Displays currently transported on Container 34.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'MI-LOCATES', stageKey: '26', stageName: 'Magic Igloo', order: 5,
    name: 'Locates / Field Cleared', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Locate process / to verify',
    completion: 'Required field locates/clearance for Magic Igloo work are complete.',
    notes: 'Beginning readiness task; technical locating remains owned by the applicable site/GIS process.',
    dependencies: [], material: 'No Display/KIT material required.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'MI-POWER', stageKey: '26', stageName: 'Magic Igloo', order: 40,
    name: 'Plug In / Power Up / Test', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'To verify',
    completion: 'Magic Igloo applicable installed work is powered/tested and verified ready.',
    notes: 'Power-up eligibility is task-specific; exact grass-cutting/readiness rule still requires leader review.',
    dependencies: ['MI-FINISH'], material: 'Installed Magic Igloo Displays and power/wiring relationships.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  },
  {
    id: 'CMD-DELIVER', stageKey: '40', stageName: 'Command Center', order: 10,
    name: 'Deliver Command Center', verification: 'UNVERIFIED',
    crew: 'To verify', duration: 'To verify', captain: 'To verify', equipment: 'Truck / delivery capability',
    completion: 'Command Center is delivered to its Stage 40 field context.',
    notes: 'Inventory-independent support/placement task with Stage 40 context.',
    dependencies: [], material: 'No Display/KIT material required unless a reviewed support relationship is later justified.',
    actual: { dates: '', crew: '', duration: '', notes: '' }
  }
];

function ensureSupplementalTasks() {
  const existingIds = new Set(state.tasks.map((task) => task.id));
  supplementalTasks.forEach((task) => {
    if (!existingIds.has(task.id)) state.tasks.push(structuredClone(task));
  });

  const frame = taskById('MI-FRAME');
  if (frame && !(frame.dependencies || []).includes('MI-LOCATES')) {
    frame.dependencies = ['MI-LOCATES', ...(frame.dependencies || [])];
  }

  saveState();
}

function ensureInstructionSection() {
  if (document.getElementById('instruction-review-section')) return;
  const materialSection = document.getElementById('detail-material')?.closest('.detail-section');
  if (!materialSection) return;

  const section = document.createElement('section');
  section.id = 'instruction-review-section';
  section.className = 'detail-section instruction-review-section';
  section.innerHTML = `
    <div class="section-title">
      <div>
        <div class="eyebrow">Procedure review</div>
        <h3>Setup Instructions</h3>
      </div>
      <span id="instruction-verification-pill" class="pill unverified">UNVERIFIED</span>
    </div>
    <div class="instruction-role-grid">
      <div class="instruction-role current">
        <strong>Current field instruction</strong>
        <span>Published PDF directly in <code>Procedures\\Setup</code></span>
        <div id="instruction-current-state" class="task-meta">Static prototype is not yet connected to the Procedure resolver.</div>
      </div>
      <div class="instruction-role working">
        <strong>Editable working source</strong>
        <span><code>Procedures\\Setup\\SourceDocs</code></span>
        <div class="task-meta">Create/use the editable copy here. Do not edit the archived historical original in place.</div>
      </div>
      <div class="instruction-role archive">
        <strong>Historical / legacy source</strong>
        <span><code>Procedures\\Setup\\Archive</code></span>
        <div class="task-meta">Review historical material here when validating the 2025 task and procedure.</div>
      </div>
    </div>
    <div class="publication-flow">
      Archive source → working copy in SourceDocs → review/edit → publish approved PDF directly in Procedures\\Setup
    </div>
    <div class="instruction-edit-grid">
      <label>Instruction verification
        <select id="instruction-verification">
          <option value="UNVERIFIED">Unverified</option>
          <option value="VERIFIED">Verified / current instruction is good</option>
          <option value="NEEDS_REVISION">Needs revision</option>
          <option value="NO_CURRENT_PDF">No current PDF / needs publishing</option>
        </select>
      </label>
      <label>Instruction review / revision notes
        <textarea id="instruction-review-notes" rows="5" placeholder="What is correct, obsolete, missing, or should change in the Setup instruction?"></textarea>
      </label>
    </div>
    <div class="action-row">
      <button id="save-instruction-review" type="button">Save Prototype Instruction Review</button>
      <button type="button" class="secondary" disabled title="Requires Procedure resolver/backend integration">Open Current PDF — connect backend</button>
      <button type="button" class="secondary" disabled title="Requires controlled authoring/publishing write path">Create Working Copy / Publish PDF — future governed write</button>
    </div>
    <div class="hint instruction-boundary">
      The production Procedure application and Display Folders mount are currently read-only. This prototype records review intent only; it does not modify Google Drive or publish PDFs.
    </div>
  `;
  materialSection.insertAdjacentElement('afterend', section);

  document.getElementById('save-instruction-review').addEventListener('click', saveInstructionReview);
}

function instructionReviewFor(task) {
  if (!task.instructionReview) {
    task.instructionReview = { status: 'UNVERIFIED', notes: '' };
  }
  return task.instructionReview;
}

function renderInstructionReview(task) {
  ensureInstructionSection();
  if (!task) return;
  const review = instructionReviewFor(task);
  const select = document.getElementById('instruction-verification');
  const notes = document.getElementById('instruction-review-notes');
  if (select) select.value = review.status || 'UNVERIFIED';
  if (notes) notes.value = review.notes || '';

  const pill = document.getElementById('instruction-verification-pill');
  if (pill) {
    const label = review.status === 'VERIFIED'
      ? 'VERIFIED'
      : review.status === 'NEEDS_REVISION'
        ? 'NEEDS REVISION'
        : review.status === 'NO_CURRENT_PDF'
          ? 'NO CURRENT PDF'
          : 'UNVERIFIED';
    pill.textContent = label;
    pill.className = `pill ${review.status === 'VERIFIED' ? 'verified' : review.status === 'UNVERIFIED' ? 'unverified' : 'correction'}`;
  }

  const currentState = document.getElementById('instruction-current-state');
  if (currentState) {
    currentState.textContent = `For Stage ${task.stageKey} — ${task.stageName}: connect the Setup app to the existing Procedure resolver to enumerate the current published PDF and Manager-only Archive/SourceDocs review sources.`;
  }
}

function saveInstructionReview() {
  const task = taskById(selectedTaskId);
  if (!task) return;
  const review = instructionReviewFor(task);
  review.status = document.getElementById('instruction-verification')?.value || 'UNVERIFIED';
  review.notes = document.getElementById('instruction-review-notes')?.value.trim() || '';
  saveState();
  renderInstructionReview(task);
}

const baseSelectTaskForInstructionReview = selectTask;
selectTask = function selectTaskWithInstructionReview(taskId) {
  baseSelectTaskForInstructionReview(taskId);
  renderInstructionReview(taskById(taskId));
};

const baseRenderAllForSupplementalTasks = renderAll;
renderAll = function renderAllWithSupplementalTasks() {
  baseRenderAllForSupplementalTasks();
  if (selectedTaskId) renderInstructionReview(taskById(selectedTaskId));
};

ensureSupplementalTasks();
ensureInstructionSection();
renderAll();
