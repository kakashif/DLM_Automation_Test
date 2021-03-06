USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Mappings]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Mappings](
	[source] [varchar](100) NOT NULL,
	[value_type] [varchar](100) NOT NULL,
	[value_from] [varchar](100) NOT NULL,
	[value_to] [varchar](100) NULL,
 CONSTRAINT [PK__SMG_Mapp__ED2ED53777031387] PRIMARY KEY CLUSTERED 
(
	[source] ASC,
	[value_type] ASC,
	[value_from] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
