USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_fixture_key_mapping]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_fixture_key_mapping](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[end_point_name] [char](32) NOT NULL,
	[league_key] [char](32) NOT NULL,
	[fixture_key] [char](255) NOT NULL,
	[fixture_key_fn] [varchar](100) NULL,
	[create_date] [datetime] NOT NULL,
	[edit_date] [datetime] NULL,
 CONSTRAINT [PK_USAT_fixture_key_mapping] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[USAT_fixture_key_mapping] ADD  CONSTRAINT [DFLT_usat_fixture_key_mapping_create_date]  DEFAULT (getdate()) FOR [create_date]
GO
