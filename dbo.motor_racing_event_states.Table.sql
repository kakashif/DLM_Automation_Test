USE [SportsDB]
GO
/****** Object:  Table [dbo].[motor_racing_event_states]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[motor_racing_event_states](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[event_id] [int] NOT NULL,
	[current_state] [tinyint] NULL,
	[sequence_number] [int] NULL,
	[lap] [varchar](100) NULL,
	[laps_remaining] [varchar](100) NULL,
	[time_elapsed] [varchar](100) NULL,
	[flag_state] [varchar](100) NULL,
	[context] [varchar](40) NULL,
	[document_id] [int] NULL,
 CONSTRAINT [PK__motor_racing_eve__114A936A] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
