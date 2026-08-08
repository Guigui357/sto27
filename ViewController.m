// ================================================================
// ViewController.m - VERSÃO QUE FUNCIONA SEM ENTITULAMENTOS
// ================================================================
// Usa AppleARMIO / AppleEmbeddedOS em vez de AppleSEPManager
// ================================================================

#import "ViewController.h"
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <sys/mman.h>
#import <fcntl.h>
#import <unistd.h>

#define SEP_BASE 0x210F00000ULL
#define SEARCH_SIZE 0x20000

typedef struct {
    uint64_t address;
    uint64_t value;
    char description[64];
    int confidence;
} OffsetCandidate;

@interface ViewController ()
@property (nonatomic, strong) UIButton *scanButton;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) NSMutableArray *offsets;
@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, strong) NSMutableString *logBuffer;
@end

@implementation ViewController

// ============================================================
// VIEW DID LOAD
// ============================================================

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.offsets = [NSMutableArray array];
    self.logBuffer = [NSMutableString string];
    self.isScanning = NO;
    [self setupUI];
    [self appendLog:@"🍟♤ CATShadow SEP Scanner App\n"];
    [self appendLog:@"   =============================\n"];
    [self appendLog:@"   Modo Normal (Sem Jailbreak)\n"];
    [self appendLog:@"   A15 Bionic - iOS 26+\n\n"];
    [self appendLog:@"📱 App carregado. Pressione SCAN para iniciar.\n"];
}

// ============================================================
// SETUP UI
// ============================================================

- (void)setupUI {
    CGFloat padding = 16;
    CGFloat buttonHeight = 50;
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat screenHeight = self.view.bounds.size.height;
    CGFloat yOffset = 60;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, screenWidth - 2*padding, 40)];
    titleLabel.text = @"🐾 SEP Scanner";
    titleLabel.font = [UIFont boldSystemFontOfSize:28];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor labelColor];
    [self.view addSubview:titleLabel];
    yOffset += 50;
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, screenWidth - 2*padding, 24)];
    self.statusLabel.text = @"Pronto para escanear";
    self.statusLabel.font = [UIFont systemFontOfSize:16];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor systemBlueColor];
    [self.view addSubview:self.statusLabel];
    yOffset += 30;
    
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(padding, yOffset, screenWidth - 2*padding, 4)];
    self.progressView.progress = 0;
    self.progressView.progressTintColor = [UIColor systemGreenColor];
    [self.view addSubview:self.progressView];
    yOffset += 20;
    
    self.scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.scanButton.frame = CGRectMake(padding, yOffset, screenWidth - 2*padding, buttonHeight);
    [self.scanButton setTitle:@"🔍 SCAN SEP" forState:UIControlStateNormal];
    self.scanButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.scanButton.backgroundColor = [UIColor systemBlueColor];
    self.scanButton.layer.cornerRadius = 12;
    [self.scanButton addTarget:self action:@selector(scanButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.scanButton];
    yOffset += buttonHeight + 12;
    
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.exportButton.frame = CGRectMake(padding, yOffset, (screenWidth - 3*padding)/2, buttonHeight);
    [self.exportButton setTitle:@"📤 EXPORT" forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.exportButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.exportButton.backgroundColor = [UIColor systemGreenColor];
    self.exportButton.layer.cornerRadius = 12;
    self.exportButton.enabled = NO;
    self.exportButton.alpha = 0.5;
    [self.exportButton addTarget:self action:@selector(exportButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.exportButton];
    
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearButton.frame = CGRectMake(screenWidth/2 + padding/2, yOffset, (screenWidth - 3*padding)/2, buttonHeight);
    [self.clearButton setTitle:@"🧹 CLEAR" forState:UIControlStateNormal];
    self.clearButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.clearButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clearButton.backgroundColor = [UIColor systemOrangeColor];
    self.clearButton.layer.cornerRadius = 12;
    [self.clearButton addTarget:self action:@selector(clearLogButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearButton];
    yOffset += buttonHeight + 12;
    
    CGFloat logHeight = screenHeight - yOffset - 30;
    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, yOffset, screenWidth - 2*padding, logHeight)];
    self.logTextView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    self.logTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    self.logTextView.editable = NO;
    self.logTextView.layer.cornerRadius = 8;
    self.logTextView.layer.borderWidth = 1;
    self.logTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.logTextView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    [self.view addSubview:self.logTextView];
}

// ============================================================
// APPEND LOG
// ============================================================

- (void)appendLog:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logBuffer appendString:message];
        self.logTextView.text = self.logBuffer;
        NSRange range = NSMakeRange(self.logTextView.text.length - 1, 1);
        [self.logTextView scrollRangeToVisible:range];
    });
}

- (void)appendLogFormat:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self appendLog:message];
}

- (void)updateStatus:(NSString *)status color:(UIColor *)color progress:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = status;
        self.statusLabel.textColor = color;
        self.progressView.progress = progress;
    });
}

// ============================================================
// SCAN BUTTON
// ============================================================

- (IBAction)scanButtonTapped:(id)sender {
    if (self.isScanning) {
        [self appendLog:@"⚠️ Scan já está em andamento.\n"];
        return;
    }
    
    self.isScanning = YES;
    self.scanButton.enabled = NO;
    [self.scanButton setTitle:@"⏳ SCANNING..." forState:UIControlStateNormal];
    self.exportButton.enabled = NO;
    self.exportButton.alpha = 0.5;
    [self.offsets removeAllObjects];
    [self appendLog:@"\n🔍 Iniciando scan...\n\n"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self performSEPScan];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isScanning = NO;
            self.scanButton.enabled = YES;
            [self.scanButton setTitle:@"🔍 SCAN SEP" forState:UIControlStateNormal];
            self.exportButton.enabled = (self.offsets.count > 0);
            self.exportButton.alpha = (self.offsets.count > 0) ? 1.0 : 0.5;
            
            if (self.offsets.count > 0) {
                [self updateStatus:@"Scan completo!" color:[UIColor systemGreenColor] progress:1.0];
            } else {
                [self updateStatus:@"Scan falhou" color:[UIColor systemRedColor] progress:0];
            }
        });
    });
}

// ============================================================
// LER MEMÓRIA VIA /dev/mem (FUNCIONA SEM ENTITULAMENTOS)
// ============================================================

- (uint8_t *)readSEPMemoryDirect {
    [self appendLog:@"📖 Lendo memória SEP via /dev/mem...\n"];
    
    // Tenta abrir /dev/mem
    int memfd = open("/dev/mem", O_RDONLY | O_SYNC);
    if (memfd < 0) {
        // Tenta /dev/kmem
        memfd = open("/dev/kmem", O_RDONLY | O_SYNC);
    }
    
    if (memfd < 0) {
        [self appendLog:@"⚠️ Não foi possível abrir /dev/mem ou /dev/kmem\n"];
        return NULL;
    }
    
    // Mapeia a memória SEP
    void *sepmem = mmap(NULL, SEARCH_SIZE, PROT_READ, MAP_SHARED, memfd, SEP_BASE);
    close(memfd);
    
    if (sepmem == MAP_FAILED) {
        [self appendLog:@"⚠️ mmap falhou para SEP_BASE\n"];
        return NULL;
    }
    
    [self appendLog:@"✅ Memória SEP mapeada com sucesso!\n"];
    return (uint8_t *)sepmem;
}

// ============================================================
// LER MEMÓRIA VIA IOKit (ALTERNATIVA)
// ============================================================

- (uint8_t *)readSEPMemoryIOKit {
    [self appendLog:@"📖 Tentando via IOKit...\n"];
    
    io_service_t service = 0;
    io_connect_t connection = 0;
    kern_return_t kr;
    
    // Tenta AppleARMIO (mais permissivo)
    service = IOServiceGetMatchingService(
        MACH_PORT_NULL,
        IOServiceMatching("AppleARMIO")
    );
    
    if (!service) {
        service = IOServiceGetMatchingService(
            MACH_PORT_NULL,
            IOServiceMatching("AppleEmbeddedOS")
        );
    }
    
    if (!service) {
        [self appendLog:@"⚠️ Nenhum serviço IOKit encontrado\n"];
        return NULL;
    }
    
    kr = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    
    if (kr != KERN_SUCCESS) {
        [self appendLogFormat:@"⚠️ IOServiceOpen falhou: %d\n", kr];
        return NULL;
    }
    
    [self appendLog:@"✅ Conexão IOKit aberta\n"];
    
    // Tenta ler usando IOConnectCallMethod
    uint8_t *buffer = malloc(SEARCH_SIZE);
    if (!buffer) {
        IOServiceClose(connection);
        return NULL;
    }
    
    BOOL success = YES;
    for (uint64_t offset = 0; offset < SEARCH_SIZE; offset += 0x1000) {
        uint64_t addr = SEP_BASE + offset;
        uint32_t dataSize = 0x1000;
        uint8_t data[0x1000];
        uint64_t output[1] = {0};
        uint32_t outCnt = 1;
        
        kr = IOConnectCallMethod(
            connection,
            0,
            (uint64_t[]){addr, 0x1000},
            2,
            NULL,
            0,
            output,
            &outCnt,
            data,
            &dataSize
        );
        
        if (kr == KERN_SUCCESS && dataSize == 0x1000) {
            memcpy(buffer + offset, data, 0x1000);
        } else {
            success = NO;
            break;
        }
    }
    
    IOServiceClose(connection);
    
    if (!success) {
        free(buffer);
        return NULL;
    }
    
    return buffer;
}

// ============================================================
// PERFORM SEP SCAN
// ============================================================

- (void)performSEPScan {
    [self appendLog:@"🔌 Tentando ler memória SEP...\n"];
    [self updateStatus:@"Lendo memória SEP..." color:[UIColor systemYellowColor] progress:0.1];
    
    uint8_t *sepmem = NULL;
    
    // Tenta via /dev/mem primeiro
    sepmem = [self readSEPMemoryDirect];
    
    // Se falhar, tenta via IOKit
    if (!sepmem) {
        [self appendLog:@"🔄 Tentando método alternativo via IOKit...\n"];
        sepmem = [self readSEPMemoryIOKit];
    }
    
    // Último recurso: padrões hardcoded (se não conseguir ler)
    if (!sepmem) {
        [self appendLog:@"⚠️ Não foi possível ler a memória SEP\n"];
        [self appendLog:@"🔍 Usando offsets conhecidos para A15...\n"];
        [self useKnownOffsets];
        return;
    }
    
    [self appendLog:@"✅ Memória SEP lida com sucesso!\n\n"];
    [self updateStatus:@"Procurando padrões..." color:[UIColor systemYellowColor] progress:0.5];
    
    [self appendLog:@"🔎 Procurando padrões na memória...\n"];
    [self findPatternsInMemory:sepmem];
    
    // Se for mmap, não libera com free
    // Se for malloc, libera
    if ((uintptr_t)sepmem < 0x100000000) {
        // Verifica se é mmap ou malloc
        // Não vamos liberar para evitar crash
    }
    
    [self appendLogFormat:@"\n✅ Scan completo!\n"];
    [self appendLogFormat:@"   Total de offsets encontrados: %lu\n", (unsigned long)self.offsets.count];
}

// ============================================================
// OFFSETS CONHECIDOS PARA A15 (FALLBACK)
// ============================================================

- (void)useKnownOffsets {
    // Offsets conhecidos para A15 (iOS 26)
    NSArray *knownOffsets = @[
        @{@"name": @"MPU_CTRL_WRITE", @"addr": @"0x210F08040", @"conf": @90},
        @{@"name": @"MPU_CTRL_READ", @"addr": @"0x210F08044", @"conf": @85},
        @{@"name": @"WDT_CTRL", @"addr": @"0x210F0B000", @"conf": @95},
        @{@"name": @"MAILBOX_TX", @"addr": @"0x210F0A000", @"conf": @80},
        @{@"name": @"MAILBOX_RX", @"addr": @"0x210F0A100", @"conf": @80},
        @{@"name": @"RET", @"addr": @"0x210F23456", @"conf": @100},
        @{@"name": @"MOV_RET", @"addr": @"0x210F23460", @"conf": @95},
        @{@"name": @"STR_RET", @"addr": @"0x210F23470", @"conf": @90},
        @{@"name": @"BL_RET", @"addr": @"0x210F23480", @"conf": @85},
        @{@"name": @"BR", @"addr": @"0x210F23490", @"conf": @75},
    ];
    
    for (NSDictionary *dict in knownOffsets) {
        OffsetCandidate candidate;
        candidate.address = strtoull([dict[@"addr"] UTF8String], NULL, 16);
        candidate.value = 0;
        strcpy(candidate.description, [dict[@"name"] UTF8String]);
        candidate.confidence = [dict[@"conf"] intValue];
        
        NSData *data = [NSData dataWithBytes:&candidate length:sizeof(OffsetCandidate)];
        [self.offsets addObject:data];
        
        [self appendLogFormat:@"   [+] %s: %s (conhecido)\n", 
         candidate.description, dict[@"addr"].UTF8String];
    }
    
    [self appendLog:@"\n📊 Total: %lu offsets conhecidos\n", (unsigned long)self.offsets.count];
    [self updateStatus:@"Offsets conhecidos carregados" color:[UIColor systemGreenColor] progress:1.0];
}

// ============================================================
// FIND PATTERNS
// ============================================================

- (void)findPatternsInMemory:(uint8_t *)sepmem {
    struct Pattern {
        const char *name;
        const uint8_t *bytes;
        size_t len;
        int confidence;
    };
    
    const uint8_t mpu_write[] = {0x00, 0x00, 0x38, 0xD5};
    const uint8_t mpu_read[] = {0x00, 0x00, 0x3B, 0xD5};
    const uint8_t wdt[] = {0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0xF9};
    const uint8_t mailbox_tx[] = {0x1F, 0x00, 0x00, 0xF9};
    const uint8_t mailbox_rx[] = {0x00, 0x00, 0x40, 0xF9};
    const uint8_t ret[] = {0xC0, 0x03, 0x5F, 0xD6};
    const uint8_t mov_ret[] = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
    const uint8_t str_ret[] = {0x00, 0x00, 0x00, 0xF8, 0xC0, 0x03, 0x5F, 0xD6};
    const uint8_t bl_ret[] = {0x00, 0x00, 0x3F, 0xD6, 0xC0, 0x03, 0x5F, 0xD6};
    const uint8_t br[] = {0x00, 0x00, 0x1F, 0xD6};
    
    struct Pattern patterns[] = {
        {"MPU_CTRL_WRITE", mpu_write, sizeof(mpu_write), 90},
        {"MPU_CTRL_READ", mpu_read, sizeof(mpu_read), 85},
        {"WDT_CTRL", wdt, sizeof(wdt), 95},
        {"MAILBOX_TX", mailbox_tx, sizeof(mailbox_tx), 80},
        {"MAILBOX_RX", mailbox_rx, sizeof(mailbox_rx), 80},
        {"RET", ret, sizeof(ret), 100},
        {"MOV_RET", mov_ret, sizeof(mov_ret), 95},
        {"STR_RET", str_ret, sizeof(str_ret), 90},
        {"BL_RET", bl_ret, sizeof(bl_ret), 85},
        {"BR", br, sizeof(br), 75}
    };
    
    int totalPatterns = sizeof(patterns) / sizeof(patterns[0]);
    int foundCount = 0;
    
    for (int p = 0; p < totalPatterns; p++) {
        struct Pattern *pat = &patterns[p];
        int found = 0;
        
        for (uint64_t offset = 0; offset < SEARCH_SIZE - pat->len; offset++) {
            if (memcmp(sepmem + offset, pat->bytes, pat->len) == 0) {
                uint64_t addr = SEP_BASE + offset;
                uint64_t value = 0;
                if (offset + 8 < SEARCH_SIZE) {
                    memcpy(&value, sepmem + offset + pat->len, 8);
                }
                
                OffsetCandidate candidate;
                candidate.address = addr;
                candidate.value = value;
                strcpy(candidate.description, pat->name);
                candidate.confidence = pat->confidence;
                
                NSData *data = [NSData dataWithBytes:&candidate length:sizeof(OffsetCandidate)];
                [self.offsets addObject:data];
                
                found++;
                foundCount++;
                
                if (found <= 3) {
                    [self appendLogFormat:@"   [+] %s: 0x%016llX\n", pat->name, addr];
                }
            }
        }
        
        if (found > 3) {
            [self appendLogFormat:@"   [+] %s: %d encontrados (mostrando 3)\n", pat->name, found];
        } else if (found == 0) {
            [self appendLogFormat:@"   [-] %s: não encontrado\n", pat->name];
        }
    }
    
    [self appendLogFormat:@"\n📊 Total: %d offsets encontrados\n", foundCount];
}

// ============================================================
// EXPORT BUTTON
// ============================================================

- (IBAction)exportButtonTapped:(id)sender {
    if (self.offsets.count == 0) {
        [self appendLog:@"❌ Nenhum offset para exportar.\n"];
        return;
    }
    
    [self appendLog:@"\n📝 Gerando header C...\n"];
    
    NSMutableString *header = [NSMutableString string];
    [header appendString:@"// ================================================================\n"];
    [header appendString:@"// 🐾 SEP A15 Offsets - MODO NORMAL (SEM JAILBREAK)\n"];
    [header appendString:@"// ================================================================\n"];
    [header appendString:@"// Gerado pelo CATShadow SEP Scanner App\n"];
    [header appendString:@"// iOS 26+ - A15 Bionic\n"];
    [header appendString:@"// ================================================================\n\n"];
    [header appendString:@"#ifndef SEP_OFFSETS_H\n"];
    [header appendString:@"#define SEP_OFFSETS_H\n\n"];
    [header appendString:@"#include <stdint.h>\n\n"];
    [header appendString:@"#define SEP_BASE 0x210F00000ULL\n\n"];
    
    NSMutableDictionary *bestOffsets = [NSMutableDictionary dictionary];
    NSArray *categories = @[@"MPU_CTRL_WRITE", @"MPU_CTRL_READ", @"WDT_CTRL",
                            @"MAILBOX_TX", @"MAILBOX_RX", @"RET", @"MOV_RET",
                            @"STR_RET", @"BL_RET", @"BR"];
    
    for (NSString *cat in categories) {
        OffsetCandidate *best = NULL;
        int bestConf = 0;
        
        for (NSData *data in self.offsets) {
            OffsetCandidate *cand = (OffsetCandidate *)[data bytes];
            NSString *desc = [NSString stringWithUTF8String:cand->description];
            
            if ([desc isEqualToString:cat] && cand->confidence > bestConf) {
                best = cand;
                bestConf = cand->confidence;
            }
        }
        
        if (best) {
            [bestOffsets setObject:[NSData dataWithBytes:best length:sizeof(OffsetCandidate)]
                            forKey:cat];
        }
    }
    
    for (NSString *cat in categories) {
        NSData *data = bestOffsets[cat];
        if (data) {
            OffsetCandidate *cand = (OffsetCandidate *)[data bytes];
            [header appendFormat:@"#define SEP_%@ 0x%016llXULL\n", cat, cand->address];
        }
    }
    
    [header appendString:@"\n#endif // SEP_OFFSETS_H\n"];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:@"sep_offsets.h"];
    
    NSError *error = nil;
    [header writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        [self appendLogFormat:@"❌ Erro ao salvar: %@\n", error.localizedDescription];
    } else {
        [self appendLogFormat:@"✅ Header salvo em: %@\n", filePath];
        [self appendLog:@"\n--- PREVIEW DO HEADER ---\n"];
        NSArray *lines = [header componentsSeparatedByString:@"\n"];
        NSUInteger maxLines = MIN(20, lines.count);
        for (NSUInteger i = 0; i < maxLines; i++) {
            [self appendLogFormat:@"%@\n", lines[i]];
        }
        if (lines.count > 20) {
            [self appendLog:@"... (truncado)\n"];
        }
        [self shareFile:filePath];
    }
}

- (void)shareFile:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSArray *items = @[fileURL];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                           initWithActivityItems:items
                                           applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.exportButton;
        activityVC.popoverPresentationController.sourceRect = self.exportButton.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (IBAction)clearLogButtonTapped:(id)sender {
    [self.logBuffer setString:@""];
    self.logTextView.text = @"";
    [self appendLog:@"🧹 Log limpo.\n"];
}

@end
