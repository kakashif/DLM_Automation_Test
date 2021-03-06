USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_content_inventory]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_content_inventory](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[vendor_id] [int] NOT NULL,
	[source_id] [varchar](200) NOT NULL,
	[source_location] [varchar](1000) NULL,
	[source_active] [bit] NOT NULL,
	[search_replace] [text] NULL,
 CONSTRAINT [PK_USAT_content_inventory] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[USAT_content_inventory] ADD  CONSTRAINT [DF_USAT_content_inventory_source_active]  DEFAULT ((0)) FOR [source_active]
GO
ALTER TABLE [dbo].[USAT_content_inventory]  WITH CHECK ADD  CONSTRAINT [FK_USAT_content_inventory_USAT_Vendor] FOREIGN KEY([vendor_id])
REFERENCES [dbo].[USAT_Vendor] ([id])
GO
ALTER TABLE [dbo].[USAT_content_inventory] CHECK CONSTRAINT [FK_USAT_content_inventory_USAT_Vendor]
GO
