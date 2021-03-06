USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_event_states]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[baseball_event_states](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[event_id] [int] NOT NULL,
	[current_state] [smallint] NULL,
	[at_bat_number] [int] NULL,
	[inning_value] [int] NULL,
	[inning_half] [varchar](100) NULL,
	[outs] [int] NULL,
	[balls] [int] NULL,
	[strikes] [int] NULL,
	[runner_on_first_id] [int] NULL,
	[runner_on_second_id] [int] NULL,
	[runner_on_third_id] [int] NULL,
	[runner_on_first] [smallint] NULL,
	[runner_on_second] [smallint] NULL,
	[runner_on_third] [smallint] NULL,
	[runs_this_inning_half] [int] NULL,
	[pitcher_id] [int] NULL,
	[batter_id] [int] NULL,
	[batter_side] [varchar](100) NULL,
	[context] [varchar](40) NULL,
	[sequence_number] [decimal](4, 1) NULL,
	[document_id] [int] NULL,
 CONSTRAINT [PK__baseball_event_s__34C8D9D1] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
