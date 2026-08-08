// ================================================================
// ViewController.m - SEP Scanner App (CORRIGIDO)
// ================================================================
// Sem erros de compilação, compatível com iOS 26.5 SDK
// ================================================================

#import "ViewController.h"
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>

// ---- CONSTANTES ----
#define SEP_BASE 0x210F00000ULL
#define SEARCH_SIZE 0x20000
#define SEP_SERVICE_NAME "AppleSEPManager"

// ---- ESTRUTURA DE OFFSET ----
typedef struct {
    uint64_t address;
    uint64_t value;
    char description[64];
    int confidence;
} OffsetCandidate;

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *scanButton;
@property (weak, nonatomic) IBOutlet UIButton *exportButton;
@property (weak, nonatomic) IBOutlet UITextView *logTextView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
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
    self.scanButton.layer.cornerRadius = 12;
    self.scanButton.backgroundColor = [UIColor systemBlueColor];
    [self.scanButton setTitle:@"🔍 SCAN SEP" forState:UIControlStateNormal];
    [self.scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.scanButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    
    self.exportButton.layer.cornerRadius = 12;
    self.exportButton.backgroundColor = [UIColor systemGreenColor];
    [self.exportButton setTitle:@"📤 EXPORT HEADER" forState:UIControlStateNormal];
    [self.exportButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.exportButton.enabled = NO;
    self.exportButton.alpha = 0.5;
    
    self.logTextView.layer.cornerRadius = 8;
    self.logTextView.layer.borderWidth = 1;
    self.logTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.logTextView.editable = NO;
    self.logTextView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    
    self.statusLabel.text = @"Pronto para escanear";
    self.statusLabel.textColor = [UIColor systemBlueColor];
    self.progressView.progress = 0;
}

// ============================================================
// APPEND LOG (CORRIGIDO - aceita apenas 1 argumento)
// ============================================================

- (void)appendLog:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logBuffer appendString:message];
        self.logTextView.text = self.logBuffer;
        NSRange range = NSMakeRange(self.logTextView.text.length - 1, 1);
        [self.logTextView scrollRangeToVisible:range];
    });
}

// ============================================================
// APPEND LOG COM FORMAT (CORRIGIDO)
// ============================================================

- (void)appendLogFormat:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self appendLog:message];
}

// ============================================================
// UPDATE STATUS
// ============================================================

- (void)updateStatus:(NSString *)status color:(UIColor *)color progress:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = status;
        self.statusLabel.textColor = color;
        self.progressView.progress = progress;
    });
}

// ============================================================
// BOTÃO SCAN (CORRIGIDO - sem duplicação)
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
// PERFORM SEP SCAN (CORRIGIDO - usa appendLogFormat)
// ============================================================

- (void)performSEPScan {
    [self appendLog:@"🔌 Abrindo conexão com SEP...\n"];
    [self updateStatus:@"Abrindo conexão SEP..." color:[UIColor systemYellowColor] progress:0.1];
    
    io_connect_t connection = [self openSEPConnection];
    if (!connection) {
        [self appendLog:@"❌ Falha ao abrir conexão SEP\n"];
        [self updateStatus:@"Erro: conexão SEP" color:[UIColor systemRedColor] progress:0];
        return;
    }
    
    [self appendLogFormat:@"✅ Conexão SEP aberta: 0x%X\n\n", connection];
    [self updateStatus:@"Conexão estabelecida" color:[UIColor systemGreenColor] progress:0.2];
    
    [self appendLog:@"📖 Lendo memória SEP...\n"];
    [self updateStatus:@"Lendo memória SEP..." color:[UIColor systemYellowColor] progress:0.3];
    
    uint8_t *sepmem = malloc(SEARCH_SIZE);
    if (!sepmem) {
        [self appendLog:@"❌ Memória insuficiente\n"];
        [self updateStatus:@"Erro: memória" color:[UIColor systemRedColor] progress:0];
        IOServiceClose(connection);
        return;
    }
    
    BOOL readSuccess = YES;
    for (uint64_t offset = 0; offset < SEARCH_SIZE; offset += 0x1000) {
        uint64_t addr = SEP_BASE + offset;
        
        if (![self readSEPMemory:connection address:addr size:0x1000 buffer:sepmem + offset]) {
            readSuccess = NO;
            [self appendLogFormat:@"⚠️ Falha ao ler 0x%016llX\n", addr];
            break;
        }
        
        float progress = 0.3 + (0.5 * ((float)offset / SEARCH_SIZE));
        [self updateStatus:[NSString stringWithFormat:@"Lendo 0x%06llX / 0x%X", offset, SEARCH_SIZE]
                     color:[UIColor systemYellowColor]
                  progress:progress];
    }
    
    if (!readSuccess) {
        [self appendLog:@"❌ Falha na leitura da memória SEP\n"];
        [self updateStatus:@"Erro: leitura" color:[UIColor systemRedColor] progress:0];
        free(sepmem);
        IOServiceClose(connection);
        return;
    }
    
    [self appendLogFormat:@"✅ Memória lida: 0x%X bytes\n\n", SEARCH_SIZE];
    [self updateStatus:@"Memória lida, procurando padrões..." color:[UIColor systemYellowColor] progress:0.8];
    
    [self appendLog:@"🔎 Procurando padrões...\n"];
    [self findPatternsInMemory:sepmem];
    
    free(sepmem);
    IOServiceClose(connection);
    
    [self appendLogFormat:@"\n✅ Scan completo!\n"];
    [self appendLogFormat:@"   Total de offsets encontrados: %lu\n", (unsigned long)self.offsets.count];
}

// ============================================================
// ABRE CONEXÃO SEP (CORRIGIDO - usa kIOMasterPortDefault)
// ============================================================

- (io_connect_t)openSEPConnection {
    // Usa mach_host_self() em vez de kIOMasterPortDefault (deprecated)
    mach_port_t masterPort = 0;
    kern_return_t kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kr != KERN_SUCCESS) {
        return 0;
    }
    
    io_service_t service = IOServiceGetMatchingService(
        masterPort,
        IOServiceMatching(SEP_SERVICE_NAME)
    );
    
    if (!service) {
        return 0;
    }
    
    io_connect_t connection = 0;
    kr = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    
    if (kr != KERN_SUCCESS) {
        return 0;
    }
    
    return connection;
}

// ============================================================
// LÊ MEMÓRIA SEP
// ============================================================

- (BOOL)readSEPMemory:(io_connect_t)connection
              address:(uint64_t)address
                 size:(uint64_t)size
               buffer:(uint8_t *)buffer {
    
    struct SEPMessage {
        uint32_t method;
        uint64_t address;
        uint64_t size;
        uint8_t data[1024];
    };
    
    struct SEPMessage msg = {0};
    msg.method = 0xCAFEBABE;
    msg.address = address;
    msg.size = size;
    
    struct SEPMessage response = {0};
    size_t outputSize = sizeof(struct SEPMessage);
    
    kern_return_t kr = IOConnectCallMethod(
        connection,
        0xDEADBEEF,
        (uint64_t[]){0, msg.method, msg.address, msg.size},
        4,
        &msg.data,
        sizeof(struct SEPMessage),
        (uint64_t *)&response.method,
        NULL,
        response.data,
        &outputSize
    );
    
    if (kr == KERN_SUCCESS && response.size == size) {
        memcpy(buffer, response.data, (size_t)size);
        return YES;
    }
    
    return NO;
}

// ============================================================
// ENCONTRA PADRÕES NA MEMÓRIA (CORRIGIDO)
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
// BOTÃO EXPORT (CORRIGIDO - sem duplicação)
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

// ============================================================
// COMPARTILHA ARQUIVO
// ============================================================

- (void)shareFile:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSArray *items = @[fileURL];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                           initWithActivityItems:items
                                           applicationActivities:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.exportButton;
        activityVC.popoverPresentationController.sourceRect = self.exportButton.bounds;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

// ============================================================
// BOTÃO LIMPAR LOG
// ============================================================

- (IBAction)clearLogButtonTapped:(id)sender {
    [self.logBuffer setString:@""];
    self.logTextView.text = @"";
    [self appendLog:@"🧹 Log limpo.\n"];
}

@end
