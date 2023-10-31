<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <xsl:param name="list" select="''"/>
  <xsl:param name="MTA" select="'sendmail'"/>
  <xsl:param name="lfsbook" select="'lfs-full.xml'"/>

<!-- Check whether the book is sysv or systemd -->
  <xsl:variable name="rev">
    <xsl:choose>
      <xsl:when test="//bookinfo/title/phrase[@revision='systemd']">
        <xsl:text>systemd</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>sysv</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:output
    method="xml"
    encoding="ISO-8859-1"
    doctype-system="http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"/>

  <xsl:include href="lfs_make_book.xsl"/>

  <xsl:template match="/">
    <book>
      <xsl:copy-of select="/book/bookinfo"/>
      <preface>
        <?dbhtml filename="preface.html"?>
        <title>Preface</title>
        <xsl:choose>
          <xsl:when test="$rev='sysv'">
            <xsl:copy-of select="id('bootscripts')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:copy-of select="id('systemd-units')"/>
          </xsl:otherwise>
        </xsl:choose>
      </preface>
      <chapter>
        <?dbhtml filename="chapter.html"?>
        <title>Installing packages in dependency build order</title>
        <xsl:call-template name="apply-list">
          <xsl:with-param name="list" select="normalize-space($list)"/>
        </xsl:call-template>
      </chapter>
      <xsl:copy-of select="id('CC')"/>
      <xsl:copy-of select="id('MIT')"/>
      <index/>
    </book>
  </xsl:template>

<!-- apply-templates for each item in the list.
     Normally, those items are id of nodes.
     Those nodes can be sect1 (normal case),
     sect2 (python/perl modules/dependencies )
     The templates after this one treat each of those cases.
     However, some items are sub-packages of compound packages (xorg7-*,
     kf5, plasma), and not id.
     We need special instructions in that case.
     The difficulty is that some of those names *are* id's,
     because they are referenced in the index.
     Hopefully, none of those id's are sect{1,2}...-->
  <xsl:template name="apply-list">
    <xsl:param name="list" select="''"/>
    <xsl:if test="string-length($list) &gt; 0">
      <xsl:choose>
        <!-- iterate if there are several packages in list -->
        <xsl:when test="contains($list,' ')">
          <xsl:call-template name="apply-list">
            <xsl:with-param name="list"
                            select="substring-before($list,' ')"/>
          </xsl:call-template>
          <xsl:call-template name="apply-list">
            <xsl:with-param name="list"
                            select="substring-after($list,' ')"/>
          </xsl:call-template>
        </xsl:when>
        <!-- From now on, $list contains only one package -->
        <!-- If it is a group, do nothing -->
        <xsl:when test="contains($list,'groupxx')"/>
        <xsl:otherwise>
          <xsl:variable name="is-lfs">
            <xsl:call-template name="detect-lfs">
              <xsl:with-param name="package" select="$list"/>
              <xsl:with-param name="lfsbook" select="$lfsbook"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="$is-lfs='true'">
            <!-- LFS package -->
              <xsl:message>
                <xsl:value-of select="$list"/>
                <xsl:text> is an lfs package</xsl:text>
              </xsl:message>
              <xsl:call-template name="process-lfs">
                <xsl:with-param name="package" select="$list"/>
                <xsl:with-param name="lfsbook" select="$lfsbook"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="contains(concat($list,' '),'-pass1 ')">
<!-- We need to do it for both sect1 and sect2, because of libva -->
              <xsl:variable
                   name="real-id"
                   select="substring-before(concat($list,' '),'-pass1 ')"/>
              <xsl:if test="id($real-id)[self::sect1]">
                <xsl:apply-templates select="id($real-id)" mode="pass1"/>
              </xsl:if>
              <xsl:if test="id($real-id)[self::sect2]">
                <xsl:apply-templates select="id($real-id)" mode="pass1-sect2"/>
              </xsl:if>
            </xsl:when>
            <xsl:when test="not(id($list)[self::sect1 or self::sect2])">
              <!-- This is a sub-package: parse the corresponding compound
                   package-->
              <xsl:apply-templates
                select="//sect1[(contains(@id,'xorg7') or
                                 contains(@id,'frameworks') or
                                 contains(@id,'plasma5'))
                                 and .//userinput/literal[contains(string(),
                                            concat($list,'-'))]]"
                   mode="compound">
                <xsl:with-param name="package" select="$list"/>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="id($list)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

<!-- The normal case : just copy to the book. Exceptions are if there
     is a xref, so use a special "mode" template -->
  <xsl:template match="sect1">
    <xsl:apply-templates select="." mode="sect1"/>
  </xsl:template>

  <xsl:template match="*" mode="pass1">
    <xsl:choose>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="@linkend='bootscripts' or
                              @linkend='systemd-units'">
                <xsl:copy-of select="."/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@linkend"/> (in full book)
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
              <xsl:if test="name() = 'id'">-pass1</xsl:if>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test=".//xref | .//@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="pass1-sect2">
    <xsl:choose>
      <xsl:when test="self::sect2">
        <xsl:element name="sect1">
          <xsl:attribute name="id"><xsl:value-of select="@id"/>-pass1</xsl:attribute>
          <xsl:attribute name="xreflabel"><xsl:value-of select="@xreflabel"/></xsl:attribute>
          <xsl:processing-instruction name="dbhtml">filename="<xsl:value-of
                          select="@id"/>-pass1.html"</xsl:processing-instruction>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::sect3">
        <xsl:element name="sect2">
          <xsl:attribute name="role">
            <xsl:value-of select="@role"/>
          </xsl:attribute>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::bridgehead">
        <xsl:element name="bridgehead">
          <xsl:attribute name="renderas">
            <xsl:if test="@renderas='sect4'">sect3</xsl:if>
            <xsl:if test="@renderas='sect5'">sect4</xsl:if>
          </xsl:attribute>
          <xsl:value-of select='.'/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="@linkend='bootscripts' or
                              @linkend='systemd-units'">
                <xsl:copy-of select="."/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@linkend"/> (in full book)
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
              <xsl:if test="name() = 'id'">-pass1</xsl:if>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test=".//xref | .//@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="processing-instruction()" mode="pass1">
    <xsl:variable name="pi-full" select="string()"/>
    <xsl:variable name="pi-value"
                  select="substring-after($pi-full,'filename=')"/>
    <xsl:variable name="filename"
                  select="substring-before(substring($pi-value,2),'.html')"/>
    <xsl:processing-instruction name="dbhtml">filename="<xsl:copy-of
                select="$filename"/>-pass1.html"</xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="processing-instruction()" mode="sect1">
    <xsl:copy-of select="."/>
  </xsl:template>

<!-- Any node which has no xref descendant is copied verbatim. If there
     is an xref descendant, output the node and recurse. -->
  <xsl:template match="*" mode="sect1">
    <xsl:choose>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="@linkend='bootscripts' or
                              @linkend='systemd-units'">
                <xsl:copy-of select="."/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@linkend"/> (in full book)
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test=".//xref">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="sect1"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<!-- Python modules and DBus bindings -->
  <xsl:template match="sect2">
    <xsl:apply-templates select='.' mode="sect2"/>
  </xsl:template>

  <xsl:template match="*" mode="sect2">
    <xsl:choose>
      <xsl:when test="self::sect2">
        <xsl:element name="sect1">
          <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
          <xsl:attribute name="xreflabel"><xsl:value-of select="@xreflabel"/></xsl:attribute>
          <xsl:processing-instruction name="dbhtml">filename="<xsl:value-of
                          select="@id"/>.html"</xsl:processing-instruction>
          <xsl:apply-templates mode="sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::sect3">
        <xsl:element name="sect2">
          <xsl:attribute name="role">
            <xsl:value-of select="@role"/>
          </xsl:attribute>
          <xsl:apply-templates mode="sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::bridgehead">
        <xsl:element name="bridgehead">
          <xsl:attribute name="renderas">
            <xsl:if test="@renderas='sect4'">sect3</xsl:if>
            <xsl:if test="@renderas='sect5'">sect4</xsl:if>
          </xsl:attribute>
          <xsl:value-of select='.'/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@linkend"/> (in full book)
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test=".//xref">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<!-- Perl modules : transform them to minimal sect1. Use a template
     for installation instructions -->
  <xsl:template match="bridgehead">
  <xsl:if test="ancestor::sect1[@id='perl-modules']">
    <xsl:element name="sect1">
      <xsl:attribute name="id"><xsl:value-of select="./@id"/></xsl:attribute>
      <xsl:attribute name="xreflabel"><xsl:value-of select="./@xreflabel"/></xsl:attribute>
      <xsl:processing-instruction name="dbhtml">
     filename="<xsl:value-of select="@id"/>.html"</xsl:processing-instruction>
      <title><xsl:value-of select="./@xreflabel"/></title>
      <sect2 role="package">
        <title>Introduction to <xsl:value-of select="@id"/></title>
        <bridgehead renderas="sect3">Package Information</bridgehead>
        <itemizedlist spacing="compact">
          <listitem>
            <para>Download (HTTP): <xsl:copy-of select="./following-sibling::itemizedlist[1]/listitem/para/ulink"/></para>
          </listitem>
          <listitem>
            <para>Download (FTP): <ulink url=" "/></para>
          </listitem>
        </itemizedlist>
      </sect2>
      <xsl:choose>
        <xsl:when test="following-sibling::itemizedlist[1]//xref[@linkend='perl-standard-install'] | following-sibling::itemizedlist[1]/preceding-sibling::para//xref[@linkend='perl-standard-install']">
          <xsl:apply-templates mode="perl-install"  select="id('perl-standard-install')"/>
        </xsl:when>
        <xsl:otherwise>
          <sect2 role="installation">
            <title>Installation of <xsl:value-of select="@xreflabel"/></title>
            <para>Run the following commands:</para>
            <for-each select="following-sibling::bridgehead/preceding-sibling::screen[not(@role)]">
              <xsl:copy-of select="."/>
            </for-each>
            <para>Now, as the <systemitem class="username">root</systemitem> user:</para>
            <for-each select="following-sibling::bridgehead/preceding-sibling::screen[@role='root']">
              <xsl:copy-of select="."/>
            </for-each>
          </sect2>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:if>
  </xsl:template>

<!-- The case of depdendencies of perl modules. Same treatment
     as for perl modules. Just easier because always perl standard -->
  <xsl:template match="para">
    <xsl:element name="sect1">
      <xsl:attribute name="id"><xsl:value-of select="./@id"/></xsl:attribute>
      <xsl:attribute name="xreflabel"><xsl:value-of select="./@xreflabel"/></xsl:attribute>
      <xsl:processing-instruction name="dbhtml">filename="<xsl:value-of
     select="@id"/>.html"</xsl:processing-instruction>
      <title><xsl:value-of select="./@xreflabel"/></title>
      <sect2 role="package">
        <title>Introduction to <xsl:value-of select="@id"/></title>
        <bridgehead renderas="sect3">Package Information</bridgehead>
        <itemizedlist spacing="compact">
          <listitem>
            <para>Download (HTTP): <xsl:copy-of select="./ulink"/></para>
          </listitem>
          <listitem>
            <para>Download (FTP): <ulink url=" "/></para>
          </listitem>
        </itemizedlist>
      </sect2>
      <xsl:apply-templates mode="perl-install"  select="id('perl-standard-install')"/>
    </xsl:element>
  </xsl:template>

<!-- copy of the perl standard installation instructions:
     suppress id (otherwise not unique) and note (which we
     do not want to apply -->
  <xsl:template match="sect2" mode="perl-install">
    <sect2 role="installation">
      <xsl:for-each select="./*">
        <xsl:if test="not(self::note)">
          <xsl:copy-of select="."/>
        </xsl:if>
      </xsl:for-each>
    </sect2>
  </xsl:template>

<!-- we have got an xorg package. We are at the installation page
     but now we need to make an autonomous page from the global
     one -->
  <xsl:template match="sect1" mode="compound">
    <xsl:param name="package"/>
    <xsl:variable name="tarball">
      <xsl:call-template name="tarball">
        <xsl:with-param name="package" select="concat(' ',$package,'-')"/>
        <xsl:with-param name="cat-md5"
                        select="string(.//userinput[starts-with(string(),'cat ')])"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- Unfortunately, there are packages in kf5 and plasma5 that
         starts in the same way: for example kwallet in kf5
         and kwallet-pam in plasma. So we may arrive here with
         package=kwallet and tarball=kwallet-pam-(version).tar.xz.
         We should not continue in this case. For checking, transform
         digits into X, and check that package-X occurs in tarball.-->
    <xsl:if test="contains(translate($tarball,'0123456789','XXXXXXXXXX'),
                           concat($package,'-X'))">
      <xsl:variable name="md5sum">
        <xsl:call-template name="md5sum">
          <xsl:with-param name="package" select="concat(' ',$package,'-')"/>
          <xsl:with-param name="cat-md5"
                          select=".//userinput[starts-with(string(),'cat ')]"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="download-dir">
        <xsl:call-template name="download-dir">
          <xsl:with-param name="package" select="concat(' ',$package,'-')"/>
          <xsl:with-param name="cat-md5"
                          select=".//userinput[starts-with(string(),'cat ')]"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="install-instructions">
        <xsl:call-template name="inst-instr">
          <xsl:with-param name="inst-instr"
            select=
              "substring-after(
                 substring-after(.//userinput[starts-with(string(),'for ') or
                                              starts-with(string(),'while ')],
                                 'pushd'),
                 '&#xA;')"/>
          <xsl:with-param name="package" select="$package"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:element name="sect1">
        <xsl:attribute name="id">
          <xsl:value-of select="$package"/>
        </xsl:attribute>
        <xsl:processing-instruction name="dbhtml">
           filename="<xsl:value-of select='$package'/>.html"
        </xsl:processing-instruction>
        <title><xsl:value-of select="$package"/></title>
        <sect2 role="package">
          <title>Introduction to <xsl:value-of select="$package"/></title>
          <bridgehead renderas="sect3">Package Information</bridgehead>
          <itemizedlist spacing="compact">
            <listitem>
              <para>Download (HTTP): <xsl:element name="ulink">
                <xsl:attribute name="url">
                  <xsl:value-of
                     select=".//para[contains(string(),'(HTTP)')]/ulink/@url"/>
                  <xsl:value-of select="$download-dir"/>
                  <!-- $download-dir contains the trailing / for xorg,
                       but not for KDE... -->
                  <xsl:if test="contains(@id,'frameworks') or
                                contains(@id,'plasma5')">
                    <xsl:text>/</xsl:text>
                  </xsl:if>
                  <!-- Some kf5 packages are in a subdirectory -->
                  <xsl:if test="$package='khtml' or
                                $package='kdelibs4support' or
                                $package='kdesignerplugin' or
                                $package='kdewebkit' or
                                $package='kjs' or
                                $package='kjsembed' or
                                $package='kmediaplayer' or
                                $package='kross' or
                                $package='kxmlrpcclient'">
                    <xsl:text>portingAids/</xsl:text>
                  </xsl:if>
                  <xsl:value-of select="$tarball"/>
                </xsl:attribute>
               </xsl:element>
              </para>
            </listitem>
            <!-- don't use FTP, although they are available for xorg -->
            <listitem>
              <para>Download (FTP): <ulink url=" "/>
              </para>
            </listitem>
            <listitem>
              <para>
                Download MD5 sum: <xsl:value-of select="$md5sum"/>
              </para>
            </listitem>
          </itemizedlist>
          <!-- If there is an additional download, we need to output that -->
          <xsl:if test=".//bridgehead[contains(string(),'Additional')]">
            <xsl:copy-of
                   select=".//bridgehead[contains(string(),'Additional')]"/>
            <xsl:copy-of
                   select=".//bridgehead[contains(string(),'Additional')]
                           /following-sibling::itemizedlist[1]"/>
          </xsl:if>
        </sect2>
        <sect2 role="installation">
          <title>Installation of <xsl:value-of select="$package"/></title>

          <para>
            Install <application><xsl:value-of select="$package"/></application>
            by running the following commands:
          </para>
          <!-- packagedir is used in xorg lib instructions -->
          <screen><userinput>packagedir=<xsl:value-of
                      select="substring-before($tarball,'.tar.')"/>
           <!-- name is used in kf5 instructions -->
            <xsl:text>
name=$(echo $packagedir | sed 's/-[[:digit:]].*//')
</xsl:text>
            <xsl:value-of select="substring-before($install-instructions,
                                                   'as_root')"/>
          </userinput></screen>

          <para>
            Now as the <systemitem class="username">root</systemitem> user:
          </para>
          <screen role='root'>
            <userinput><xsl:value-of select="substring-after(
                                                   $install-instructions,
                                                   'as_root')"/>
            </userinput>
          </screen>
        </sect2>
      </xsl:element><!-- sect1 -->
    </xsl:if>

  </xsl:template>

<!-- get the tarball name from the text that comes from the .md5 file -->
  <xsl:template name="tarball">
    <!-- $package must start with a space, and finish with a "-", to be
         sure to match exactly the package. Note that if we have two
         packages named e.g. "pkg1" and "pkg1-add", the second one may be
         matched by " pkg1-". So this only works if "pkg1" comes before
         "pkg1-add" in the md5 file. Presently this is the case in the book...
    -->
    <xsl:param name="package"/>
    <xsl:param name="cat-md5"/>
    <xsl:choose>
      <xsl:when test="contains(substring-before($cat-md5,$package),'&#xA;')">
        <xsl:call-template name="tarball">
          <xsl:with-param name="package" select="$package"/>
          <xsl:with-param name="cat-md5"
                          select="substring-after($cat-md5,'&#xA;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains(substring-before($cat-md5,$package),' ')">
        <xsl:call-template name="tarball">
          <xsl:with-param name="package" select="$package"/>
          <xsl:with-param name="cat-md5"
                          select="substring-after($cat-md5,' ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="substring-after(
                                substring-before($cat-md5,'&#xA;'),' ')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
<!-- get the download dirname from the text that comes from the .md5 file -->
  <xsl:template name="download-dir">
    <xsl:param name="package"/>
    <xsl:param name="cat-md5"/>
    <xsl:choose>
      <xsl:when test="not(@id='xorg7-legacy')">
        <xsl:copy-of select="''"/>
      </xsl:when>
      <xsl:when test="contains(substring-before($cat-md5,$package),'&#xA;')">
        <xsl:call-template name="download-dir">
          <xsl:with-param name="package" select="$package"/>
          <xsl:with-param name="cat-md5"
                          select="substring-after($cat-md5,'&#xA;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains(substring-before($cat-md5,$package),' ')">
        <xsl:call-template name="download-dir">
          <xsl:with-param name="package" select="$package"/>
          <xsl:with-param name="cat-md5"
                          select="substring-after($cat-md5,' ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="substring-before($cat-md5,' ')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
<!-- same for md5sum -->
  <xsl:template name="md5sum">
    <xsl:param name="package"/>
    <xsl:param name="cat-md5"/>
    <xsl:choose>
      <xsl:when test="contains(substring-before($cat-md5,$package),'&#xA;')">
        <xsl:call-template name="md5sum">
          <xsl:with-param name="package" select="$package"/>
          <xsl:with-param name="cat-md5"
                          select="substring-after($cat-md5,'&#xA;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="substring-before($cat-md5,'  ')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="inst-instr">
    <!-- This template is necessary because of the "kapidox" case in kf5:
         Normally, the general instructions extract the package and change
         to the extracted dir for running the installation instructions.
         When installing a sub-package of a compound package, the installation
         instructions to be run are located between a pushd and a popd,
         *except* for kf5, where a popd occurs inside a case for kapidox...
         So we call this template with a "inst-instr" string that contains
         everything after the pushd.-->
    <xsl:param name="inst-instr"/>
    <xsl:param name="package"/>
    <xsl:choose>
      <!-- first the case of kf5: there are two "popd"-->
      <xsl:when test="contains(substring-after($inst-instr,'popd'),'popd')">
        <xsl:choose>
          <xsl:when test="$package='kapidox'">
            <!-- only the instructions inside the "case" and before popd -->
            <xsl:copy-of select="substring-after(substring-before($inst-instr,'popd'),'kapidox)')"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- all what is after the esac -->
            <xsl:call-template name="inst-instr">
              <xsl:with-param
                name="inst-instr"
                select="substring-after($inst-instr,'esac&#xA;')"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <!-- normal case: everything that is before popd -->
        <xsl:copy-of select="substring-before($inst-instr,'popd')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
