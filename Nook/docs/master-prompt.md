> Original project brief supplied on 2026-11-02. Product name updated to Nook; the current milestone request takes precedence over the original start instruction.

# Build Nook — A Real-Time Collaborative Whiteboard

I want you to help me build a complete web application called **Nook** using **Elixir, Phoenix, and Phoenix LiveView**.

I am a computer science student learning Elixir and Phoenix. This is a project I want to enjoy building, learn from, and potentially use with other people.

Please act as an experienced software engineer and help me build this application incrementally, with clean, maintainable code and explanations of important technical decisions.

**IMPORTANT:** I have attached an image showing the toolbar design I want. Use it as a visual reference for the overall interface, icon style, layout, spacing, colors, and simplicity.

## 1. Project Overview

Nook is a collaborative, infinite whiteboard where users can freely place elements anywhere on a canvas, connect ideas, organize notes and tasks, and collaborate with friends in real time.

The application should feel like a mixture of a digital whiteboard and a flexible visual workspace.

It is NOT primarily a business meeting planner or a traditional project management application.

People should be able to use Nook for anything:
- Brainstorming ideas
- Designing games or software
- School projects
- Organizing thoughts
- Visual planning
- Sharing ideas with friends
- Creating diagrams and connections
- Quick, temporary whiteboard sessions

**The main goal is freedom, simplicity, and an exceptionally smooth user experience.**

I particularly dislike how cluttered or awkward many existing whiteboard applications feel. I want Nook to be intuitive enough that someone can immediately understand how to use it.

## 2. Technology Requirements

Use the following stack:

- Elixir
- Phoenix Framework
- Phoenix LiveView
- PostgreSQL
- Ecto
- Phoenix PubSub
- Phoenix Presence
- JavaScript hooks where necessary for smooth canvas interactions
- Tailwind CSS for styling, using the conventions of the selected Phoenix version

Do not introduce Ash Framework unless there is a compelling technical reason. I prefer starting with standard Phoenix and Ecto to reduce unnecessary complexity.

Follow current Phoenix conventions and use the installed framework versions.

The interface should primarily use Phoenix LiveView. However, animations, dragging, panning, zooming, and other frequent pointer interactions should happen locally in JavaScript when appropriate so the experience remains smooth.

## 3. User Accounts and Temporary Boards

There should be two primary ways to create a board.

### Quick Board — No Account Required

Anyone should be able to open the website and immediately create a temporary whiteboard without registering.

Requirements:
- One-click board creation.
- No sign-in requirement.
- Users can start adding elements immediately.
- Temporary boards can be shared through links or room codes.
- Temporary boards are saved server-side for their limited lifetime.
- Temporary boards expire after a configurable inactivity period, initially seven days.
- Clearly communicate expiration to users.
- Allow a temporary board to be claimed and saved permanently by creating an account.

Use securely generated, unguessable identifiers or tokens for guest access. Do not rely on room codes alone for authorization.

### Registered Users

Registered users should be able to:
- Create an account and log in.
- Create permanent boards.
- Rename and delete their boards.
- Access a dashboard showing their boards.
- Reopen previously saved boards.
- Invite other people.
- Manage sharing permissions.
- Claim eligible temporary boards.

Use Phoenix's standard authentication approach.

## 4. Infinite Whiteboard Canvas

The whiteboard is the most important part of the application.

Requirements:
- Infinite canvas.
- Smooth panning.
- Smooth zooming centered around the pointer.
- Drag-and-drop element positioning.
- Adjustable element sizes where appropriate.
- Click-to-select interactions.
- Double-click-to-edit interactions.
- Automatic saving.
- A subtle dotted background.
- Minimal visual clutter.
- Responsive interface.
- Reliable coordinate handling while zoomed or panned.

The experience should feel immediate and fluid.

Do not depend on server round trips for every mouse movement.

The UI should update locally during movement, with changes synchronized to the server at appropriate intervals or at the end of an interaction.

## 5. Top Toolbar

Use the attached toolbar image as the main visual reference.

The toolbar should be horizontally positioned near the top of the whiteboard, with rounded corners, subtle shadows, clean icons, and readable labels.

**The toolbar order must be exactly:**

1. Text
2. Note
3. Shapes
4. Task
5. Connect
6. File
7. Idea
8. Room

### Text

Allows users to place standalone text anywhere on the whiteboard.

Users should be able to edit the text, change its size and color, and move it freely.

### Note

Creates a sticky-note-style element.

Features:
- Editable text.
- Multiple background colors.
- Movable and resizable.
- Simple, clean appearance.

### Shapes

Opens a small selection menu containing shapes such as:
- Rectangle
- Circle
- Triangle
- Diamond
- Rounded rectangle

Users select a shape and place it anywhere on the canvas.

Shapes should be resizable and customizable.

### Task

Creates a task element containing:
- Task title
- Checkbox
- Optional description
- Completion status

Tasks should function like other movable canvas elements, rather than being restricted to a separate task list.

### Connect

**This is an element-connection tool, NOT a multiplayer connection button.**

It should allow users to visually connect two elements, such as a note and a shape, or two different ideas.

Interaction:
1. Click Connect.
2. Select the first element.
3. Select the second element.
4. Display a visible line or arrow connecting them.

Connections should remain attached when either element is moved.

Eventually, support different line styles and arrowheads.

### File

Allows users to place file-related elements onto the board.

Initially, support visual document/file icons that can be moved and labeled.

Later, expand to actual file uploads, attachments, and previews.

### Idea

Uses a lightbulb icon to represent a new idea.

Clicking the tool should create a customizable idea element that users can place anywhere.

It could have a distinctive appearance while sharing the same editing and dragging behavior as other elements.

### Room

This is the multiplayer sharing feature.

The Room button should open a simple sharing interface containing:
- Current room code
- Copyable invitation link
- Button to copy the room code
- Connected participants
- Option to join a room
- Sharing permissions, where appropriate

The Room button should be visually distinct from Connect, because they serve completely different purposes.

## 6. Click-to-Place Interaction

This is a core UX requirement.

I want users to click a tool in the toolbar and then click anywhere on the canvas to place that element.

For example:

1. Click Note.
2. Move the mouse over the canvas.
3. See a preview indicating where the note will appear.
4. Click to place the note.
5. Immediately edit or move the note.

Use this same interaction pattern for Text, Shapes, Task, File, and Idea.

For Connect, use the two-element selection system described above.

Pressing Escape should cancel the active placement tool.

Users should always have a clear indication of which tool is active.

The interface should be predictable and require very few clicks.

## 7. Real-Time Collaboration

Multiple people should be able to edit a board simultaneously.

Requirements:
- Share boards using invitation links.
- Join boards using short room codes.
- Allow guest participation without registration.
- Synchronize element creation, movement, editing, and deletion.
- Show connected participants.
- Show changes without refreshing.
- Ensure users joining an existing board receive its current state.
- Validate all changes and permissions on the server.

Use Phoenix PubSub and Phoenix Presence.

Use a simple, documented conflict-handling strategy initially, with element revisions to detect stale updates. More sophisticated collaborative editing algorithms can come later if necessary.

## 8. Universal Canvas Element Architecture

I want the application to use a flexible architecture where most canvas elements share common functionality.

For example, elements should generally support:
- Unique identifiers
- Type
- Position
- Dimensions
- Color and appearance
- Selection
- Moving
- Editing
- Deleting
- Layer ordering
- Persistence
- Collaboration synchronization

Different element types should have different content and rendering, but common interactions should not need to be reimplemented separately for every tool.

Design the database and component architecture to make additional element types straightforward to add.

## 9. Visual Design

Follow the attached reference image.

Priorities:
- Clean, minimalist interface.
- Light theme initially.
- Rounded toolbar.
- Soft shadows.
- Pleasant, restrained accent colors.
- Simple icons.
- Subtle dotted canvas background.
- Clear selected-tool indication.
- A compact, unobtrusive interface.
- Small contextual editing controls that appear when an element is selected.

Avoid:
- Large, permanent sidebars.
- Excessive menus.
- Complicated tool selection.
- Unnecessary animations.
- Cluttered controls.
- Interfaces that require many clicks for common actions.

The whiteboard should occupy most of the screen.

Smoothness and usability matter more than adding lots of features.

## 10. Development Milestones

Build the application incrementally.

### Milestone 1 — Foundation and Canvas Prototype
- Create the Phoenix application.
- Set up PostgreSQL and Ecto.
- Create a minimal board page.
- Implement the initial toolbar.
- Create the infinite canvas.
- Implement basic panning and zooming.
- Implement click-to-place for one text element or note.
- Implement smooth dragging.

**Success condition:** I can open a local webpage, click a toolbar tool, place an element, and move it smoothly.

### Milestone 2 — Core Toolbox and Persistence
- Add the remaining basic element types.
- Implement element editing and deletion.
- Add basic shapes.
- Implement element resizing.
- Persist boards and elements in PostgreSQL.
- Make the toolbar function consistently.

**Success condition:** A solo user can build a useful whiteboard, refresh the page, and recover their work.

### Milestone 3 — Guest Boards and Accounts
- Implement temporary boards without registration.
- Add authentication.
- Build a personal board dashboard.
- Add permanent board saving.
- Allow eligible temporary boards to be claimed.
- Implement secure access controls.

**Success condition:** Guests can use the application immediately, while registered users can keep permanent boards.

### Milestone 4 — Sharing and Multiplayer
- Add room codes.
- Add invitation links.
- Implement joining boards.
- Add Phoenix PubSub synchronization.
- Show connected users with Presence.
- Handle concurrent edits and basic conflicts.

**Success condition:** Two users in separate browsers can work on the same board simultaneously.

### Milestone 5 — Connections and Advanced Canvas Features
- Implement connections between elements.
- Automatically update connection geometry when elements move.
- Improve multi-selection, resizing, and keyboard shortcuts.
- Add simple grouping functionality.
- Improve performance for larger boards.

**Success condition:** Users can build visual diagrams with connected objects and organize complex boards smoothly.

### Milestone 6 — Polish and Deployment
- Add comprehensive testing.
- Improve loading and error states.
- Refine the visual design.
- Add accessibility improvements.
- Test collaboration under real conditions.
- Configure production deployment.

## 11. How I Want You to Work

Please do not attempt to build the entire application in one enormous step.

I want to understand the code and make decisions along the way.

Follow these rules:

1. Start by inspecting the existing project directory and development environment.
2. If the directory is empty, scaffold a new Phoenix application using current conventions.
3. Explain important architectural choices briefly.
4. Work on one milestone at a time.
5. Implement working functionality rather than only mockups.
6. Include automated tests for important backend behaviors.
7. Run relevant tests and verify the application after implementing features.
8. Keep code organized and maintainable.
9. Avoid unnecessary packages and complexity.
10. Do not introduce advanced features before the core experience works.
11. Preserve the exact toolbar order and the overall style shown in the image.
12. If an implementation detail is unspecified, make a sensible choice, explain it briefly, and proceed.

**Start with Milestone 1.**

First, inspect the project directory and available Elixir/Phoenix tooling. Then give me a concise implementation plan for the first milestone and begin implementing the foundation and interactive canvas prototype.

The ultimate goal is to create a genuinely useful, beautiful, and enjoyable collaborative whiteboard that feels simpler and smoother than existing alternatives.